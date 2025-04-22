unit UIManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, SQLite3Conn, SQLDB, SimpleSQLite3, MiscFunctions;

procedure LoadLayoutMap;

implementation

uses DatabaseManager;

procedure LoadLayoutMap;
var
  Ini: TIniFile;
  ComponentList, FieldList, GlobalFields: TStringList;
  Component, FieldName, RawLine, FieldLabel, GroupName, ComponentType, ComboValues, comboBlock: string;
  i, j, pipePos, semiPos, SortOrder, closePos: integer;
  Q: TSQLQuery;
begin
  S3DB.ExecuteDirect('DROP TABLE if exists LayoutMap');
  S3DB.ExecuteDirect('CREATE TABLE LayoutMap (Origin TEXT, Component TEXT, FieldName TEXT, FieldLabel TEXT, GroupName TEXT, SortOrder INTEGER, ComponentType TEXT, ComboValues TEXT)');
  S3DB.Transaction.Commit;

  Ini := TIniFile.Create('Structure.ini');
  ComponentList := TStringList.Create;
  FieldList := TStringList.Create;
  GlobalFields := TStringList.Create;
  Ini.ReadSection('ORDER', ComponentList);
  Ini.ReadSection('GLOBAL', GlobalFields);

  Q := NewQuery(S3DB);
  try
    // Handle component-specific sections
    for i := 0 to ComponentList.Count - 1 do begin
      Component := ComponentList[i];
      Ini.ReadSection(Component, FieldList);
      SortOrder := 0;

      for j := 0 to FieldList.Count - 1 do begin
        FieldName := Trim(FieldList[j]);
        if (FieldName = '') or (GlobalFields.IndexOf(FieldName) <> -1) then begin
          Continue;
        end;

        RawLine := Ini.ReadString(Component, FieldName, '');
        FieldLabel := FieldName;
        GroupName := '';
        ComponentType := 'Text';
        ComboValues := '';

        semiPos := Pos(';', RawLine);
        if semiPos > 0 then begin
          FieldLabel := Copy(RawLine, semiPos + 1, MaxInt);
        end;

        pipePos := Pos('|', FieldLabel);
        if pipePos > 0 then begin
          GroupName := Trim(Copy(FieldLabel, pipePos + 1, MaxInt));
          FieldLabel := Trim(Copy(FieldLabel, 1, pipePos - 1));
        end else begin
          FieldLabel := Trim(FieldLabel);
        end;

        // Type detection
        if Pos(lowercase('Combo['), lowercase(RawLine)) = 1 then begin
          ComponentType := 'Combo';
          closePos := Pos(']', RawLine);
          if closePos > 0 then begin
            comboBlock := Copy(RawLine, 7, closePos - 7);
            ComboValues := StringReplace(comboBlock, '_', LineEnding, [rfReplaceAll]);
          end;
        end else if Pos(lowercase('Integer'), LowerCase(RawLine)) = 1 then begin
          ComponentType := 'Integer';
        end;

        Q.SQL.Text := 'INSERT INTO LayoutMap (Origin, Component, FieldName, FieldLabel, GroupName, SortOrder, ComponentType, ComboValues) VALUES (:grp, :comp, :field, :label, :groupname, :sort, :type, :combo)';
        Q.ParamByName('grp').AsString := 'C';
        Q.ParamByName('comp').AsString := Component;
        Q.ParamByName('field').AsString := FieldName;
        Q.ParamByName('label').AsString := FieldLabel;
        Q.ParamByName('groupname').AsString := GroupName;
        Q.ParamByName('sort').AsInteger := SortOrder;
        Q.ParamByName('type').AsString := ComponentType;
        Q.ParamByName('combo').AsString := ComboValues;
        Q.ExecSQL;

        Inc(SortOrder);
      end;
    end;

    // Handle [GLOBAL] fields
    Ini.ReadSection('GLOBAL', FieldList);
    SortOrder := 0;
    for j := 0 to FieldList.Count - 1 do begin
      FieldName := Trim(FieldList[j]);
      if FieldName = '' then begin
        continue;
      end;

      RawLine := Ini.ReadString('GLOBAL', FieldName, '');
      FieldLabel := FieldName;
      ComponentType := 'Text';
      ComboValues := '';

      semiPos := Pos(';', RawLine);
      if semiPos > 0 then begin
        FieldLabel := Copy(RawLine, semiPos + 1, MaxInt);
      end;
      FieldLabel := Trim(FieldLabel);

      if Pos(lowercase('Combo['), lowercase(RawLine)) = 1 then begin
        ComponentType := 'Combo';
        closePos := Pos(']', RawLine);
        if closePos > 0 then begin
          comboBlock := Copy(RawLine, 7, closePos - 7);
          ComboValues := StringReplace(comboBlock, '_', LineEnding, [rfReplaceAll]);
        end;
      end else if Pos(lowercase('Integer'), LowerCase(RawLine)) = 1 then begin
        ComponentType := 'Integer';
      end;

      Q.SQL.Text := 'INSERT INTO LayoutMap (Origin, Component, FieldName, FieldLabel, GroupName, SortOrder, ComponentType, ComboValues) ' +
        'VALUES (:grp, :comp, :field, :label, :groupname, :sort, :type, :combo)';
      Q.ParamByName('grp').AsString := 'G';
      Q.ParamByName('comp').AsString := 'GLOBAL';
      Q.ParamByName('field').AsString := FieldName;
      Q.ParamByName('label').AsString := FieldLabel;
      Q.ParamByName('groupname').AsString := '';
      Q.ParamByName('sort').AsInteger := SortOrder;
      Q.ParamByName('type').AsString := ComponentType;
      Q.ParamByName('combo').AsString := ComboValues;
      Q.ExecSQL;

      Inc(SortOrder);
    end;

  finally
    EndQuery(Q);
    Ini.Free;
    ComponentList.Free;
    FieldList.Free;
    GlobalFields.Free;
  end;
end;

initialization
  LoadLayoutMap;

end.
