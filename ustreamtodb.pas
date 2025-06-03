unit uStreamToDB;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB;

type
  tWhatINeedToKnow = class
    // Database Use: This is passed in as an already existing SQlite3 DBO -- We're not creating an object against this
    Database: TSQLite3Connection;
    // TableToWorkWith Use: This is the table that we're reading/writing from/to.
    TableToWorkWith: string;
    // FieldForBlob Use: This is the field that's handling our raw data
    FieldForBlob: string;
    // FieldForID Use: This is used to define the name of the record ID (Not SQLite3s RowID) is
    FieldForID: string;
    // RecordID Use:
    // - For reading and updating, this is what we're running the SELECT statement with
    // - For writing, this is what is returned after an INSERT
    RecordID: integer;
    // CompressedContent Use:
    // - If true, we KNOW the data is encrypted, so we'll do the required work regardless
    // - If false, no compression, period.
    CompressedContent: boolean;
  public
    constructor Create;
  end;

procedure StreamToDB (var WhatINeedToKnow: tWhatINeedToKnow; StreamData: TMemoryStream);
procedure DbToStream (var WhatINeedToKnow: tWhatINeedToKnow; out StreamData: TMemoryStream);

function DecompressZlib (Input: tMemoryStream; ExpectedSize: QWord): TMemoryStream;
function CompressZlib (Input: tMemoryStream): TMemoryStream;

implementation

uses
  ZLib, Forms, DB;

function CompressZlib (Input: tMemoryStream): TMemoryStream;
var
  SrcLen, DstLen: uLongf;
  DestBuf: pBytef;
  Status: integer;
begin
  SrcLen := Input.Size;
  DstLen := SrcLen + (SrcLen div 10) + 12;

  GetMem(DestBuf, DstLen);

  // ✳️ DstLen is passed as pointer
  Status := compress(DestBuf, @DstLen, pBytef(Input.Memory), SrcLen);
  if Status <> Z_OK then begin
    raise Exception.CreateFmt('Compression failed: %d', [Status]);
  end;

  Result := TMemoryStream.Create;
  Result.WriteBuffer(DestBuf^, DstLen);
  Result.Position := 0;

  FreeMem(DestBuf);
end;

function DecompressZlib (Input: tMemoryStream; ExpectedSize: QWord): TMemoryStream;
var
  SrcLen: uLongf;
  DstLen: QWord;
  DestBuf: pbyte;
  Status: integer;
begin
  SrcLen := Input.Size;
  DstLen := ExpectedSize;

  GetMem(DestBuf, DstLen);
  try
    Status := uncompress(pBytef(DestBuf), @DstLen, pBytef(Input.Memory), SrcLen);
    if Status <> Z_OK then begin
      raise Exception.CreateFmt('Decompression failed: %d', [Status]);
    end;

    Result := TMemoryStream.Create;
    Result.WriteBuffer(DestBuf^, DstLen);
    Result.Position := 0;
  finally
    FreeMem(DestBuf);
  end;
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

constructor tWhatINeedToKnow.Create;
begin
  Database := nil;
  TableToWorkWith := '';
  FieldForBlob := '';
  FieldForID := '';
  RecordID := -1;
  CompressedContent := False;
end;


procedure StreamToDB (var WhatINeedToKnow: tWhatINeedToKnow; StreamData: TMemoryStream);
var
  q: TSQLQuery;
  WhatIKnow: tWhatINeedToKnow; // Just for shortening strings.  "WhatINeedToKnow" won't be changed as a rule of thumb specifically on that name, even though we're assigning WhatIKnow to WhatINeedToKnow.
  MemStream: TMemoryStream;
  OriginalSize: int64;
  sql: string;
begin
  WhatIKnow := WhatINeedToKnow;
  q := TSQLQuery.Create(nil);
  q.Database := WhatIKnow.Database;
  q.Transaction := WhatIKnow.Database.Transaction;
  // Get the data prepped to send
  StreamData.Position := 0;
  if WhatIKnow.CompressedContent then begin
    // Start at the beginning of the stuffs to be compressed
    MemStream := CompressZlib(StreamData);
    // Tag on the original size of the data to extract later
    MemStream.Position := MemStream.Size;
    OriginalSize := StreamData.Size;
    MemStream.WriteQWord(OriginalSize);
  end else begin
    MemStream.CopyFrom(StreamData, StreamData.Size);
  end;

  // Prepare the query
  MemStream.Position := 0;

  // Are we inserting or updating?
  if WhatIKnow.RecordID = -1 then begin
    // We're inserting
    with WhatIKnow do begin
      sql := format('insert into %s (%s) values (:%s)', [TableToWorkWith, FieldForBlob, FieldForBlob]);
    end;
    q.SQL.Text := sql;
  end else begin
    // We're updating
    with WhatIKnow do begin
      sql := Format('update %s set %s=:%s where %s=:%s', [TableToWorkWith, FieldForBlob, FieldForBlob, FieldForID, FieldForID]);
    end;
    q.SQL.Text := sql;
    q.ParamByName(WhatIKnow.FieldForID).AsInteger := WhatIKnow.RecordID;
  end;
  q.ParamByName(WhatIKnow.FieldForBlob).LoadFromStream(MemStream, ftBlob);
  q.ExecSQL;

  // If we're doing an insert, we need to return the last inserted ID
  if WhatIKnow.RecordID = -1 then begin
    Q.SQL.Text := 'SELECT last_insert_rowid() AS ImageID;';
    Q.Open;
    WhatIKnow.RecordID := Q.FieldByName('ImageID').AsInteger;
  end;
  EndQuery(q);

end;

procedure DbToStream (var WhatINeedToKnow: tWhatINeedToKnow; out StreamData: TMemoryStream);
var
  q: TSQLQuery;
  WhatIKnow: tWhatINeedToKnow;
  MemStream: TMemoryStream;
  CompressedStream: TMemoryStream;
  OriginalSize: QWord;
  SQL: string;
begin
  WhatIKnow := WhatINeedToKnow; // Just internalising the conversation with myself of what I need to know versus what I do know.
  q := TSQLQuery.Create(nil);
  q.Database := WhatIKnow.Database;
  q.Transaction := WhatIKnow.Database.Transaction;

  with WhatIKnow do begin
    sql := Format('select %s from %s where %s=:%s', [FieldForBlob, TableToWorkWith, FieldForID, FieldForID]);
  end;
  q.SQL.Text := sql;
  q.ParamByName(WhatIKnow.FieldForID).AsInteger := WhatIKnow.RecordID;
  q.Open;
  Application.MessageBox(PChar(IntToStr(q.RecordCount)), PChar('wtf'), 0);

  if not q.EOF then begin
    // Now the fun part... Getting the blob....
    MemStream := TMemoryStream.Create;
    if not q.FieldByName(WhatIKnow.FieldForBlob).IsNull then begin
      TBlobField(q.FieldByName(WhatIKnow.FieldForBlob)).SaveToStream(MemStream);
      if WhatIKnow.CompressedContent then begin
        if MemStream.Size > SizeOf(int64) then begin
          MemStream.Position := MemStream.Size - SizeOf(int64);
          OriginalSize := MemStream.ReadQWord;
          MemStream.Position := 0;
          CompressedStream := TMemoryStream.Create;
          CompressedStream.Position := 0;
          CompressedStream.CopyFrom(MemStream, MemStream.Size - sizeof(int64));
          StreamData := DecompressZlib(CompressedStream, OriginalSize);
          CompressedStream.Free;
        end else begin
          // We've got nothing/something illegal in the database field for this call, so, just return an empty stream
          StreamData := TMemoryStream.Create;
        end;
      end else begin
        StreamData := TMemoryStream.Create;
        StreamData.CopyFrom(MemStream, MemStream.Size);
      end;
      MemStream.Free;
    end;
  end else begin
    StreamData := TMemoryStream.Create;
  end;
  EndQuery(q);
end;


end.
