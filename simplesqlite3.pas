(*
@AI:unit-summary: This Pascal unit provides functionality for managing SQLite3 database connections, including opening and closing connections, creating and finalizing SQL queries, checking for the existence of tables and specific records (builds) in the database based on identifiers or QR codes.
*)
unit SimpleSQLite3;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB;

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
(*
@AI:summary: This function opens a SQLite3 database connection using the specified database name. This routine also establishes the transaction objects, and a busy_timeout.
@AI:params: dbName: The filename of the database to be opened.
@AI:params: DBObj: An output parameter that will hold the database connection object upon successful opening.
@AI:returns: A boolean indicating whether the database connection was successfully opened.
*)
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
(*
@AI:summary: This function closes a SQlite3 database file connection safely. It also cleans up any transactions that are open prior to clearing the DBobj variable
@AI:params: DBObj: Represents the database connection object that needs to be closed.
@AI:returns: No output is expected.
*)
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
(*
@AI:summary: Creates a new SQL query object associated with a given SQLite3 database connection.  This prepares the related Transaction object already assigned to the DBObj.
@AI:params: DBObj: The database connection object used to execute the SQL queries.
@AI:returns: A new SQL query object for interacting with the database.
*)
var
  q: TSQLQuery;
begin
  q := TSQLQuery.Create(nil);
  q.Database := DBObj;
  q.Transaction := DBObj.Transaction;
  Result := q;
end;

procedure EndQuery (var Query: tSQLQuery);
(*
@AI:summary: This function likely finalizes or closes a SQL query operation.
@AI:params: Query: Represents the SQL query object that is being processed or terminated.
@AI:returns: No output is expected.
*)
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
(*
@AI:summary: Checks if a specified table exists in the given SQLite database connection.
@AI:params: DBObj: The database connection object used to access the SQLite database.
@AI:params: TableName: The name of the table to check for existence in the database.
@AI:returns: Returns true if the table exists, otherwise false.
*)
var
  dbList: TStringList;
begin
  dbList := TStringList.Create;
  try
    DBObj.GetTableNames(dbList);
    Result := dbList.IndexOf(TableName) <> -1;
  finally
    dbList.Free;
  end;
end;

function BuildExists (DBObj: TSQLite3Connection; BuildID: integer): boolean; overload;
(*
@AI:summary: Checks if a specific build exists in the database. A build is typically a computer case, or a set of components that are part of a build.
@AI:params: DBObj: The database connection object used to interact with the SQLite database.
@AI:params: BuildID: The unique identifier for the build being checked for existence.
@AI:returns: Returns true if the build exists, otherwise false.
@AI:notes: This is a PASCAL OVERRIDEN function.  This function looks at the BuildID.
*)
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
(*
@AI:summary: This function checks if a specific QR code exists in the database.
@AI:params: DBObj: Represents the database connection to be used for the query.
@AI:params: QRCode: The QR code string that needs to be checked for existence in the database.
@AI:returns: A boolean indicating whether the QR code exists in the database.
@AI:notes: This is a PASCAL OVERRIDEN function.  This function looks at the QRCode.
*)
var
  q: TSQLQuery;
  r: integer;
begin
  q := NewQuery(DBObj);
  q.SQL.Text := 'select count(BuildID) BuildCount from BuildList where QRCode=:QRCode';
  q.Params.ParamValues['QRCode'] := QRCode;
  q.Open;
  r := q.FieldByName('BuildCount').AsInteger;
  EndQuery(q);
  Result := r = 1;
end;


end.
