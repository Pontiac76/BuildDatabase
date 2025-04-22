unit DatabaseManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn;

procedure DefineBuildList;
procedure DefineBuildComponents;
procedure DefineDevices;
procedure StopOnNotZeroTrans;

var
  S3DB: TSQLite3Connection;

procedure dbExec (Query: string);

implementation

uses Forms, LCLType, IniFiles, SQLite3, SQLDB, DB, SimpleSQLite3, frmDebug, StdCtrls,
  Controls,
  ShellAPI, Windows;// Used for shipping out to a shell for the SQL code

var
  slTableList: TStringList;

const
  CRLF = chr(13) + chr(10);

procedure StopOnNotZeroTrans;
var
  tc: integer;
begin
  tc := S3DB.TransactionCount;
  //  if tc > 0 then begin
  //    application.Terminate;
  //  end;
end;

procedure dbExec (Query: string);
var
  vQuery: TSQLQuery;
begin
  vQuery := NewQuery(S3DB);
  vQuery.SQL.Text := Query;
  vQuery.ExecSQL;
  vQuery.Free;
end;

function GetTableFields (const AConnection: TSQLite3Connection; const ATableName: string): string;
var
  Query: TSQLQuery;
  sl: TStringList;
begin
  sl := TStringList.Create;
  Query := TSQLQuery.Create(nil);
  try
    Query.Database := AConnection;
    Query.SQL.Text := 'PRAGMA table_info(' + ATableName + ')';
    Query.Open;

    while not Query.EOF do begin
      sl.Add(Query.FieldByName('name').AsString);
      //      Writeln('Field Name: ', Query.FieldByName('name').AsString);
      Query.Next;
    end;

    Query.Close;
  finally
    Query.Free;
    Result := sl.Text;
    sl.Free;
  end;
end;

function FieldExists (const AConnection: TSQLite3Connection; const ATableName: string; const AFieldName: string): boolean;
var
  FieldList: TStringList;
begin
  FieldList := TStringList.Create;
  FieldList.Text := GetTableFields(AConnection, ATableName);
  Result := FieldList.IndexOf(AFieldName) <> -1;
  FieldList.Free;
end;

procedure SafeDelete (var sl: TStringList; Content: string);
begin
  if sl.IndexOf(Content) <> -1 then begin
    sl.Delete(sl.IndexOf(Content));
  end;
end;


procedure GetMergedFieldDefinitions (Ini: TIniFile; SectionName: string; GlobalFields, SectionFields, FieldMap: TStringList);
var
  i: integer;
  Key, Value: string;
begin
  // Load [GLOBAL] fields
  Ini.ReadSection('GLOBAL', GlobalFields);
  for i := 0 to GlobalFields.Count - 1 do begin
    Key := Trim(GlobalFields[i]);

    // Skip if the key is blank or a comment
    if (Key <> '') and (Key[1] <> '#') then begin
      Value := Trim(Ini.ReadString('GLOBAL', Key, ''));

      // Use the field if it has a label (semicolon) or some kind of content
      if (Pos(';', Value) > 0) or (Value <> '') then begin
        FieldMap.Values[Key] := Value;
      end // If the field just has a type (like "text"), add the key again as its label
      else if (Pos(';', Value) = 0) and (Pos('=', Value) > 0) then begin
        FieldMap.Values[Key] := Value + ';' + Key;
      end;
    end;
  end;

  // Load fields from the section we’re working on, and override GLOBAL if needed
  Ini.ReadSection(SectionName, SectionFields);
  for i := 0 to SectionFields.Count - 1 do begin
    Key := Trim(SectionFields[i]);

    // Skip if the key is blank or a comment
    if (Key <> '') and (Key[1] <> '#') then begin
      Value := Trim(Ini.ReadString(SectionName, Key, ''));

      // Use the field if it has a label or any real content
      if (Pos(';', Value) > 0) or (Value <> '') then begin
        FieldMap.Values[Key] := Value;
      end // Fill in the label if it's missing, using the key name as the label
      else if (Pos(';', Value) = 0) and (Pos('=', Value) > 0) then begin
        FieldMap.Values[Key] := Value + ';' + Key;
      end;
    end;
  end;
end;

function BuildCreateTableStatement (TableName: string; FieldMap: TStringList): string;
var
  SQL: TStringList;
  FieldName, FieldDef, SQLType: string;
  i: integer;
begin
  SQL := TStringList.Create;
  try
    SQL.Add('CREATE TABLE ' + TableName + ' (');

    for i := 0 to FieldMap.Count - 1 do begin
      FieldName := FieldMap.Names[i];
      FieldDef := FieldMap.ValueFromIndex[i];

      // Parse SQL type from the field definition
      if Pos(';', FieldDef) > 0 then begin
        SQLType := Trim(Copy(FieldDef, 1, Pos(';', FieldDef) - 1));
      end else begin
        SQLType := Trim(FieldDef);
      end;

      // Convert Combo[...] to TEXT for schema
      if Pos('combo[', LowerCase(SQLType)) = 1 then begin
        SQLType := 'TEXT';
      end;

      // Emit each line
      if i = 0 then begin
        SQL.Add('  ' + FieldName + ' ' + SQLType);
      end else begin
        SQL.Add('  , ' + FieldName + ' ' + SQLType);
      end;
    end;

    SQL.Add(');');
    Result := StringReplace(SQL.Text, sLineBreak, ' ', [rfReplaceAll]);
  finally
    SQL.Free;
  end;
end;

function StartSchemaEditForTable (TableName: string; SQLSteps: TStringList): TStringList;
var
  FieldStr: string;
  OldFields: TStringList;
begin
  FieldStr := GetTableFields(S3DB, TableName);  // multi-line string
  OldFields := TStringList.Create;
  OldFields.Text := FieldStr;  // splits on CRLF

  SQLSteps.Add('ALTER TABLE ' + TableName + ' RENAME TO ' + TableName + '_backup;');
  Result := OldFields;
end;

function GenerateInsertStatement (const TableName: string; const FieldMap, OldFields: TStringList): string;
var
  SharedFields: TStringList;
  i: integer;
begin
  SharedFields := TStringList.Create;
  try
    for i := 0 to FieldMap.Count - 1 do begin
      if OldFields.IndexOf(FieldMap.Names[i]) <> -1 then begin
        SharedFields.Add(FieldMap.Names[i]);
      end;
    end;

    Result := 'INSERT INTO ' + TableName +
      ' (' + SharedFields.CommaText + ') ' +
      'SELECT ' + SharedFields.CommaText +
      ' FROM ' + TableName + '_backup;';
  finally
    SharedFields.Free;
  end;
end;

procedure ExecuteSQLSteps (SQLSteps: TStringList);
var
  i: integer;
  q: TSQLQuery;
begin
  q := NewQuery(S3DB);
  try
    for i := 0 to SQLSteps.Count - 1 do begin
      q.SQL.Text := SQLSteps[i];
      q.ExecSQL;
    end;
  finally
    EndQuery(q);  // var parameter — will close, commit, free, and clean up q
  end;
end;


procedure ShowSQLInNotepadAndWait (const FilePath: string);
begin
  ShellExecute(0, 'open', PChar(FilePath), nil, nil, SW_SHOWNORMAL);
end;

procedure InjectRootSQLMadness (const TableName: string; SQLSteps: TStringList);
begin
  // Prepend (in reverse order for insert-at-top)
  SQLSteps.Insert(0, 'SAVEPOINT [_apply_design_transaction];');
  SQLSteps.Insert(0, 'PRAGMA [main].foreign_keys = ''off'';');
  SQLSteps.Insert(0, 'PRAGMA [main].legacy_alter_table = ''on'';');
  SQLSteps.Insert(0, 'DROP INDEX IF EXISTS [main].[uidx_' + TableName + '_QRCode];');

  // Append cleanup
  SQLSteps.Add('DROP TABLE IF EXISTS ' + TableName + '_backup;');
  SQLSteps.Add('CREATE UNIQUE INDEX [main].[uidx_' + TableName + '_QRCode] ON [' + TableName + ']([QRCode]);');
  SQLSteps.Add('RELEASE [_apply_design_transaction];');
  SQLSteps.Add('PRAGMA [main].foreign_keys = ''on'';');
  SQLSteps.Add('PRAGMA [main].legacy_alter_table = ''off'';');
end;

function CleanSQLStatement (const SQL: string): string;
var
  S: string;
begin
  S := SQL;

  // Normalize multi-space to single space
  while Pos('  ', S) > 0 do begin
    S := StringReplace(S, '  ', ' ', [rfReplaceAll]);
  end;

  // Remove spaces after '('
  S := StringReplace(S, '( ', '(', [rfReplaceAll]);

  // Remove spaces before ')'
  S := StringReplace(S, ' )', ')', [rfReplaceAll]);

  // Remove spaces before commas
  S := StringReplace(S, ' ,', ',', [rfReplaceAll]);

  // Remove spaces after commas
  S := StringReplace(S, ', ', ',', [rfReplaceAll]);

  // Final trim
  Result := Trim(S);
end;

procedure AddFieldToTable (TableName, IniGroup: string);
var
  Ini: TIniFile;
  GlobalFields, SectionFields, MergedFields: TStringList;
  FieldMap, SQLSteps, OldFields: TStringList;
  CreateLine, InsertLine: string;
begin
  Ini := TIniFile.Create('Structure.ini');
  GlobalFields := TStringList.Create;
  SectionFields := TStringList.Create;
  MergedFields := TStringList.Create;
  FieldMap := TStringList.Create;
  SQLSteps := TStringList.Create;
  OldFields := nil;
  try
    // Step 1: Load merged field definitions (GLOBAL + section)
    GetMergedFieldDefinitions(Ini, IniGroup, GlobalFields, SectionFields, FieldMap);

    if TableExists(S3DB, TableName) then // Step 2: Begin schema modification (grab old fields and queue rename)
    begin
      OldFields := StartSchemaEditForTable(TableName, SQLSteps);
    end else begin
      OldFields := TStringList.Create;
    end;

    // Step 3: Build CREATE TABLE statement
    CreateLine := CleanSQLStatement(BuildCreateTableStatement(TableName, FieldMap));
    SQLSteps.Add(CreateLine);

    // Step 4: Build INSERT INTO ... SELECT ... statement using intersected fields
    if OldFields.Count > 0 then begin
      InsertLine := CleanSQLStatement(GenerateInsertStatement(TableName, FieldMap, OldFields));
      SQLSteps.Add(InsertLine);
    end;

    // Step 5: Finish schema modification (drop backup table)
    InjectRootSQLMadness(TableName, SQLSteps);

    // Step 6: Execute SQL steps in order
    SQLSteps.SaveToFile('sql_debug.txt');
    //ShowSQLInNotepadAndWait('sql_debug.txt');
    ExecuteSQLSteps(SQLSteps);

  finally
    Ini.Free;
    GlobalFields.Free;
    SectionFields.Free;
    MergedFields.Free;
    FieldMap.Free;
    SQLSteps.Free;
    if Assigned(OldFields) then begin
      OldFields.Free;
    end;
  end;
end;

function fTableList: string;
begin
  s3db.GetTableNames(slTableList);
  Result := slTableList.Text;
end;

// These two define the non-dynamic tables.
procedure DefineBuildList;
begin
  slTableList.Text := fTableList;
  if slTableList.IndexOf('BuildList') = -1 then begin
    dbExec('CREATE TABLE [BuildList]([BuildID] INTEGER PRIMARY KEY ASC AUTOINCREMENT,[BuildQR] TEXT UNIQUE,[BuildName] TEXT,UNIQUE([BuildQR]) ON CONFLICT FAIL);');
    dbExec('CREATE INDEX [idxBuildQR] ON [BuildList]([BuildQR] COLLATE [NOCASE] ASC);');
  end;
end;

procedure DefineBuildComponents;
begin
  slTableList.Text := fTableList;
  if slTableList.IndexOf('BuildComponents') = -1 then begin
    dbExec('CREATE TABLE [BuildComponents]([BuildID] INTEGER,[ComponentID] INTEGER,UNIQUE([ComponentID] ASC) ON CONFLICT FAIL);');
    dbExec('CREATE UNIQUE INDEX [idxBuildComponents] ON [BuildComponents]([BuildID],[ComponentID]);');
  end;
end;

procedure MergeSectionWithGlobal (Ini: TIniFile; SectionName: string; var MergedFields: TStringList);
var
  GlobalFields, SectionFields: TStringList;
  i: integer;
  Key: string;
begin
  GlobalFields := TStringList.Create;
  SectionFields := TStringList.Create;
  MergedFields.Clear;
  try
    Ini.ReadSection('GLOBAL', GlobalFields);
    Ini.ReadSection(SectionName, SectionFields);

    // Start with global fields
    for i := 0 to GlobalFields.Count - 1 do begin
      Key := GlobalFields[i];
      if SectionFields.IndexOf(Key) = -1 then // Only add if not overridden
      begin
        MergedFields.Add(Key);
      end;
    end;

    // Then add section-specific fields (which may override global)
    MergedFields.AddStrings(SectionFields);

    // 🔧 Post-merge cleanup
    for i := MergedFields.Count - 1 downto 0 do begin
      Key := Trim(MergedFields[i]);
      if Key = '' then begin
        MergedFields.Delete(i);
      end;
    end;
  finally
    GlobalFields.Free;
    SectionFields.Free;
  end;
end;

procedure DefineDevices;
var
  ini: TIniFile;
  ListOfComponentTypes: TStringList;
  ListOfFieldsForComponent: TStringList;
  KeyValues: TStringList;
  x, y: integer;
  IniGroup: string;
  TableName, FieldName, FieldDefinition: string;
begin
  ini := TIniFile.Create('Structure.ini');
  ListOfComponentTypes := TStringList.Create;
  ListOfFieldsForComponent := TStringList.Create;
  KeyValues := TStringList.Create;

  ini.ReadSection('ORDER', ListOfComponentTypes);
  for x := 0 to ListOfComponentTypes.Count - 1 do begin
    IniGroup := ListOfComponentTypes[x];

    MergeSectionWithGlobal(ini, IniGroup, ListOfFieldsForComponent);
    TableName := 'Device_' + StringReplace(IniGroup, ' ', '', [rfReplaceAll]);

    for y := 0 to ListOfFieldsForComponent.Count - 1 do begin
      FieldName := StringReplace(ListOfFieldsForComponent[y], ' ', '', [rfReplaceAll]); // DB Table Field name
      if not FieldExists(S3DB, TableName, FieldName) then begin
        FieldDefinition := ini.ReadString(IniGroup, FieldName, '');
        if FieldDefinition = '' then begin
          FieldDefinition := ini.ReadString('GLOBAL', FieldName, '');
        end;
        AddFieldToTable(TableName, IniGroup);
      end;
    end;
  end;

  ini.Free;
  ListOfComponentTypes.Free;
  ListOfFieldsForComponent.Free;
  KeyValues.Free;
end;


initialization
  slTableList := TStringList.Create;
  if not OpenDB('ComputerDatabase.sqlite3', s3db) then begin
    Application.MessageBox('Could not open ComputerDatabase.sqlite3', 'Error', MB_OK);
    application.Terminate;
  end;
  StopOnNotZeroTrans;
  DefineBuildList;
  StopOnNotZeroTrans;
  DefineBuildComponents;
  StopOnNotZeroTrans;
  DefineDevices;
  StopOnNotZeroTrans;

finalization
  slTableList.Free;

end.
