(*
@AI:unit-summary: This Pascal unit manages database operations for an SQLite3 database, specifically focusing on defining and manipulating tables related to computer builds and their components. It includes functionalities for executing SQL commands, checking field existence, merging configuration fields from an INI file, and dynamically creating or modifying database schemas based on predefined structures.
*)
unit DatabaseManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn;

procedure DefineBuildList;
procedure DefineBuildComponents;
procedure DefineDevices;

var
  S3DB: TSQLite3Connection;

const
  CRLF = chr(13) + chr(10);

procedure dbExec (Query: string);

implementation

uses Forms, LCLType, IniFiles, SQLite3, SQLDB, DB, SimpleSQLite3, frmDebug, StdCtrls,
  Controls, ShellAPI, Windows;// Used for shipping out to a shell for the SQL code


procedure dbExec (Query: string);
(*
@AI:summary: Executes a database query provided as a string. This creates a transaction safe execution of the query.
@AI:params: Query: The SQL query string to be executed against the database.
@AI:returns: No output is expected.
*)
var
  vQuery: TSQLQuery;
begin
  vQuery := NewQuery(S3DB);
  vQuery.SQL.Text := Query;
  vQuery.ExecSQL;
  EndQuery(vQuery);
end;

function GetTableFields (AConnection: TSQLite3Connection; ATableName: string): string;
(*
@AI:summary: Retrieves the field names of a specified table from a SQLite database connection.
@AI:params: AConnection: The database connection used to access the SQLite database.
@AI:params: ATableName: The name of the table whose fields are to be retrieved.
@AI:returns: A string containing the names of the fields in the specified table.  This return can be assigned directly into tStringList.Text.
*)
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
(*
@AI:summary: Checks if a specified field exists in a given table within a SQLite database connection.
@AI:params: AConnection: The database connection used to access the SQLite database.
@AI:params: ATableName: The name of the table where the field is being checked.
@AI:params: AFieldName: The name of the field to verify its existence in the specified table.
@AI:returns: Returns true if the field exists, otherwise returns false.
*)
var
  FieldList: TStringList;
begin
  FieldList := TStringList.Create;
  FieldList.Text := GetTableFields(AConnection, ATableName);
  Result := FieldList.IndexOf(AFieldName) <> -1;
  FieldList.Free;
end;

procedure SafeDelete (var sl: TStringList; Content: string);
(*
@AI:summary: This function appears to safely delete a specified content from a TStringList.
@AI:params: sl: The TStringList from which the content will be deleted.
@AI:params: Content: The string that needs to be removed from the TStringList.
@AI:returns:
*)
begin
  if sl.IndexOf(Content) <> -1 then begin
    sl.Delete(sl.IndexOf(Content));
  end;
end;

procedure GetMergedFieldDefinitions (Ini: TIniFile; SectionName: string; GlobalFields, SectionFields, FieldMap: TStringList);
(*
@AI:summary: This function will take first take in all [Global] keys in the Ini section, then read in in the [SectionName] keys, and then puts the GlobalFields and SectionFields into FieldMap ensuring that there's a unique set of keys.  Global entries are overridden by whatever is provided in the SectionFields.
@AI:params: Ini: Represents the INI file from which to read the field definitions.
@AI:params: SectionName: Specifies the section in the INI file to retrieve field definitions from.
@AI:params: GlobalFields: A list to store global field definitions that may be merged.
@AI:params: SectionFields: A list to store field definitions specific to the given section.
@AI:params: FieldMap: A list to map the fields from global and section-specific definitions.
@AI:returns: This function does not return a value.
*)
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
(*
@AI:summary: Generates a SQL CREATE TABLE statement based on the provided table name and field definitions.
@AI:params: TableName: The name of the table to be created in the database.
@AI:params: FieldMap: A list of fields and their definitions to be included in the CREATE TABLE statement.
@AI:returns: A string containing the complete SQL CREATE TABLE statement.
*)
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

(*
@AI:summary: Initiates an editing session for a specified database table using a series of SQL commands.
@AI:params: TableName: The name of the table to be edited.
@AI:params: SQLSteps: A list of SQL commands to be executed during the editing session.
@AI:returns: A list of strings representing the results or status of the SQL commands executed.
*)
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
(*
@AI:summary: Generates an SQL INSERT statement for a specified table using provided field mappings and old field values.
@AI:params: TableName: The name of the database table for which the INSERT statement is generated.
@AI:params: FieldMap: A list of fields and their corresponding values to be inserted into the table.
@AI:params: OldFields: A list of existing field values that may be referenced or compared during the generation of the INSERT statement.
@AI:returns: A string representing the constructed SQL INSERT statement.
*)
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

    Result := 'INSERT INTO ' + TableName + ' (' + SharedFields.CommaText + ') ' + 'SELECT ' + SharedFields.CommaText + ' FROM ' + TableName + '_backup;';
  finally
    SharedFields.Free;
  end;
end;

procedure ExecuteSQLSteps (SQLSteps: TStringList);
(*
@AI:summary: Executes a series of SQL commands provided in a list.
@AI:params: SQLSteps: A list of SQL commands to be executed sequentially.
@AI:returns: No output is expected.
*)
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
(*
@AI:summary: This function specified SQL file in Notepad and waits for the user to close it.  This is a debugging tool and does not affect anything with the database.
@AI:params: FilePath: The path to the SQL file that will be opened in Notepad.
@AI:returns: No output is expected.
*)
begin
  ShellExecute(0, 'open', PChar(FilePath), nil, nil, SW_SHOWNORMAL);
end;


procedure InjectRootSQLMadness (const TableName: string; SQLSteps: TStringList);
(*
@AI:summary: This function prepares and then resets the SQLite3 database to be able to manage table schemas directly.
@AI:params: TableName: The name of the database table where SQL commands will be injected.
@AI:params: SQLSteps: A list of SQL commands to be executed on the specified table.
@AI:returns: No output is expected from this procedure.
*)
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
(*
@AI:summary: Cleans the SQL line to reduces the number of spaces in the actual query and tightens up the byte count we're sending through a string.
@AI:params: SQL: The SQL statement to be cleaned and validated.
@AI:returns: A sanitized version of the input SQL statement.
*)
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
(*
@AI:summary: This function adds a new field to a specified table in the SQLite3 database.
@AI:params: TableName: The name of the table to which the field will be added.
@AI:params: IniGroup: The initial group or category for the new field being added.
@AI:returns:
*)
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

procedure MergeSectionWithGlobal (Ini: TIniFile; SectionName: string; var MergedFields: TStringList);
(*
@AI:summary: Merges specified section fields from a global configuration into a provided string list.
@AI:params: Ini: Represents the configuration file containing global settings to be merged.
@AI:params: SectionName: The name of the section to be merged from the configuration file.
@AI:params: MergedFields: A string list that will hold the merged fields after the operation.
@AI:returns:
*)
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

procedure DefineBuildList;
(*
@AI:summary: This function initializes the SQLite3 table that holds the list of Builds we have in the database.
@AI:params: None.
@AI:returns: None.
@AI:Note: DefineBuildList is not dynamically created or managed by the structure.ini file.  This just ensures the table exists at all.
*)
begin
  if not TableExists(S3DB, 'BuildList') then begin
    dbExec('Drop Index if exists [idxBuildQR]');
    dbExec('CREATE TABLE [BuildList]([BuildID] INTEGER PRIMARY KEY ASC AUTOINCREMENT,[BuildQR] TEXT UNIQUE,[BuildName] TEXT,UNIQUE([BuildQR]) ON CONFLICT FAIL);');
    dbExec('CREATE INDEX [idxBuildQR] ON [BuildList]([BuildQR] COLLATE [NOCASE] ASC);');
  end;
end;

procedure DefineBuildComponents;
(*
@AI:summary: This function ensures that the BuildComponents table exists in SQlite3.  This table holds the relationship to what builds hold what components.
@AI:params: None.
@AI:returns: None.
*)
begin
  if not TableExists(s3db, 'BuildComponents') then begin
    dbExec('drop index if exists [idxBuildComponents]');
    dbExec('CREATE TABLE [BuildComponents]([BuildID] INTEGER,[Component] TEXT NOT NULL,[ComponentID] INTEGER);');
    dbExec('CREATE UNIQUE INDEX [idxBuildComponents] ON [BuildComponents](BuildID, Component, ComponentID);');
  end;
end;

procedure DefineComponentImages;
begin
  if not TableExists(s3db, 'ComponentImages') then begin
    dbExec('Drop Index if exists idxComponentImages;');
    dbExec('CREATE TABLE [ComponentImages]([ImageID] INTEGER PRIMARY KEY AUTOINCREMENT,[ComponentType] TEXT NOT NULL,[ComponentID] INTEGER NOT NULL,[FileName] TEXT NOT NULL,[CRC32] TEXT NOT NULL,[Format] TEXT NOT NULL,[Width] INTEGER,[Height] INTEGER,[OriginalFileName] TEXT,[LastCRCCheck] DATETIME,[UncompressedSize] INTEGER NOT NULL, [RawData] BLOB NOT NULL);');
    dbExec('CREATE INDEX [idxComponentImages] ON [ComponentImages]([ComponentType] ASC,[ComponentID] ASC);');
  end;
end;

(*
@AI:summary: This function creates the Device_Component tables based on the IaC instructions found in the structure.ini.  This function will call the required functions to generate additional fields or create the tables if missing.
@AI:params: None.
@AI:returns: None.
*)
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
(*
@AI:initialization-summary: Initializes core components and establishes necessary connections for the application.
@AI:initialization-actions:
- Opens a database connection using the global variable S3DB to enable SQLite3 data access globally, which is critical for application functionality for the life of the application.
- We then ensure that the table that holds the list of computer builds exists
- We then ensure that the table that holds the relationships between the builds and the components.  What components belong to what builds.
- We then ensure that we have the dynamicly created and controlled via structures.ini Device_[Components] tables is defined
@AI:GlobalVars:
- s3db: Global use tSqlite3Database object.  Application wide.  Terminated/freed in another unit.
*)
  if not OpenDB('ComputerDatabase.sqlite3', s3db) then begin
    Application.MessageBox('Could not open ComputerDatabase.sqlite3', 'Error', MB_OK);
    application.Terminate;
  end;
  DefineBuildList;
  DefineDevices;
  DefineBuildComponents;
  DefineComponentImages;

finalization

end.
