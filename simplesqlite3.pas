unit SimpleSQLite3;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLite3, SQLDB;

function OpenDB (const dbName: string; out DBObj: TSQLite3Connection): boolean;
procedure CloseDB (var DBObj: tSqlite3Connection);
function NewQuery (DBObj: TSQLite3Connection): TSQLQuery;
procedure EndQuery (var Query: tSQLQuery);
function TableExists (var DBObj: TSQLite3Connection; TableName: string): boolean;

// Just some quick query functions
function BuildExists (DBObj: TSQLite3Connection; BuildID: integer): boolean; overload;
function BuildExists (DBObj: TSQLite3Connection; QRCode: string): boolean; overload;


implementation


function OpenDB (const dbName: string; out DBObj: TSQLite3Connection): boolean;
var
  conSQLite3: TSQLite3Connection;
  transSQLite3: TSQLTransaction;
begin
  Result := False;

  // Create components
  conSQLite3 := TSQLite3Connection.Create(nil);
  transSQLite3 := TSQLTransaction.Create(nil);

  try
    // Link transaction to database
    transSQLite3.Database := conSQLite3;
    conSQLite3.Transaction := transSQLite3;

    // Setup database properties
    conSQLite3.DatabaseName := dbName;
    conSQLite3.HostName := 'localhost';
    conSQLite3.CharSet := 'UTF8';
    // Open database
    conSQLite3.Params.Values['busy_timeout'] := '5000';
    conSQLite3.Open;

    // Ensure database is open before returning
    if conSQLite3.Connected then begin
      DBObj := conSQLite3;
      Result := True;
    end else begin
      conSQLite3.Close;
    end;
  except
    on E: Exception do begin
      conSQLite3.Close;
      transSQLite3.Free;
      conSQLite3.Free;
      Result := False;
    end;
  end;
end;

procedure CloseDB (var DBObj: TSQLite3Connection);
begin
  // disconnect
  if Assigned(DBObj) then begin
    if DBObj.Connected then begin
      TSQLTransaction(DBObj.Transaction).Commit;
      DBObj.Close;
    end;

    // release
    TSQLTransaction(DBObj.Transaction).Free;
    DBObj.Free;
  end;
end;

function NewQuery (DBObj: TSQLite3Connection): TSQLQuery;
var
  q: TSQLQuery;
begin
  q := TSQLQuery.Create(nil);
  q.Database := DBObj;
  q.Transaction := DBObj.Transaction;
  Result := q;
end;

procedure EndQuery (var Query: tSQLQuery);
var
  LocalDB: TSQLite3Connection;
  LastTransCount: integer;
begin
  LocalDB := TSQLite3Connection(Query.DataBase);
  LastTransCount := LocalDB.TransactionCount;
  LocalDB.Transaction.Commit;
  while LocalDB.TransactionCount > 1 do begin
    LocalDB.Transaction.Commit;
    if LastTransCount <> LocalDB.TransactionCount then begin
      LastTransCount := LocalDB.TransactionCount;
      LocalDB.Transaction.Commit;
    end;
  end;
  Query.Close;
  Query.Free;
end;

function TableExists (var DBObj: TSQLite3Connection; TableName: string): boolean;
var
  dbList: TStringList;
begin
  dbList := TStringList.Create;
  DBObj.GetTableNames(dbList);
  Result := dbList.IndexOf(TableName) <> -1;
  dbList.Free;
end;

function BuildExists (DBObj: TSQLite3Connection; BuildID: integer): boolean; overload;
var
  q: TSQLQuery;
  r: integer;
begin
  q := NewQuery(DBObj);
  q.SQL.Text := 'select count(BuildID) BuildCount from BuildList where BuildID=:BuildID';
  q.Params.ParamValues['BuildID'] := BuildID;
  q.Open;
  r := q.FieldByName('BuildCount').AsInteger;
  EndQuery(q);
  Result := r = 1;
end;

function BuildExists (DBObj: TSQLite3Connection; QRCode: string): boolean; overload;
begin

end;


end.
