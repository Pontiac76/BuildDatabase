unit frmBuildSheet;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls, ExtCtrls;

type

  { TBuildSheet }

  TBuildSheet = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    btnExportNoQR: TButton;
    btnExportFull: TButton;
    btnRenameModel: TButton;
    btnSaveModel: TButton;
    btnDeleteModel: TButton;
    btnSaveSheet: TButton;
    btnClearSheet: TButton;
    btnSearch: TButton;
    cboBuildSheetModel: TComboBox;
    Edit1: TEdit;
    gbBuildSheets: TGroupBox;
    Label1: TLabel;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    ScrollBox1: TScrollBox;
    StringGrid1: TStringGrid;
    procedure ApplicationProperties1Idle (Sender: TObject; var Done: boolean);
    procedure btnExportFullClick (Sender: TObject);
    procedure btnExportNoQRClick (Sender: TObject);
    procedure btnDeleteModelClick (Sender: TObject);
    procedure btnRenameModelClick (Sender: TObject);
    procedure btnSaveModelClick (Sender: TObject);
    procedure btnClearSheetClick (Sender: TObject);
    procedure btnSaveSheetClick (Sender: TObject);
    procedure btnSearchClick (Sender: TObject);
    procedure cboBuildSheetModelChange (Sender: TObject);
    procedure FormCreate (Sender: TObject);
    procedure FormDestroy (Sender: TObject);
    procedure FormResize (Sender: TObject);
    procedure gbBuildSheetsResize (Sender: TObject);
    procedure StringGrid1SetEditText (Sender: TObject; ACol, ARow: integer; const Value: string);
    procedure ValidateNumbers (Sender: TObject);
  private
    procedure RepopulateForm;
    procedure RegenSheetModels;
    procedure CreateComponentCounters;
    procedure NewSheetDB;
    procedure CheckSheet;
    procedure SaveSheet;
    procedure LoadSheet;

    function rOrder: string;
    function rSafeOrder: string;

    property IniOrder: string read rOrder;
    property IniSafeOrder: string read rSafeOrder;
  public

  end;

var
  BuildSheet: TBuildSheet;


implementation

uses SQLite3Conn, SQLite3, SQLDB, SimpleSQLite3, DatabaseManager, MiscFunctions,
  LCLType, Clipbrd, IniFiles, Math;

  {$R *.lfm}

  { TBuildSheet }

var
  CompsToDelete: TList;
  BuildSheetDB: TSQLite3Connection;
  lOrder: TStringList;
  lSafeOrder: TStringList;

procedure TBuildSheet.FormCreate (Sender: TObject);
begin
  CompsToDelete := TList.Create;

  RepopulateForm;
end;

procedure TBuildSheet.cboBuildSheetModelChange (Sender: TObject);
var
  x: integer;
  Order: TStringList;
  Edit: TEdit;
  q: TSQLQuery;
  BuildSheetID: integer;
begin
  Order := TStringList.Create;
  Order.Text := rOrder;
  // Fill everything up with zeros, since the BuildSheetList may not have a valid entry
  for x := 0 to Order.Count - 1 do begin
    Edit := tEdit(FindAnyComponent(ScrollBox1, 'txt' + SafeComponentName(Order[x])));
    Edit.Text := '1';
  end;
  Order.Free;

  // Populate the text fields that exist
  if cboBuildSheetModel.ItemIndex > 0 then begin
    BuildSheetID := O2I(cboBuildSheetModel.Items.Objects[cboBuildSheetModel.ItemIndex]);
    q := NewQuery(s3db);
    q.SQL.Text := 'select * from BuildSheetLists where BuildSheetID=:BSID';
    q.ParamByName('BSID').AsInteger := BuildSheetID;
    q.Open;
    while not q.EOF do begin
      Edit := tEdit(FindAnyComponent(ScrollBox1, q.FieldByName('ComponentName').AsString));
      Edit.Text := trim(q.FieldByName('ComponentCount').AsString);
      q.Next;
    end;
    EndQuery(q);
  end;

  // Take whatever we have in the grid, and put it into the RAM database
  SaveSheet;
  // Now let's check whats on the sheet
  CheckSheet;
  // Now put the proper contents ON the sheet.
  LoadSheet;
end;

procedure TBuildSheet.btnSaveModelClick (Sender: TObject);
var
  ModelName: string;
  ModelID: integer;
  q: TSQLQuery;
  x: integer;
  Order: TStringList;
  Edit: TEdit;
begin
  if cboBuildSheetModel.ItemIndex = 0 then begin
    ModelName := trim(InputBox('New Model Name', 'Enter the name of this Build Sheet Model', ''));
    if ModelName <> '' then begin
      q := NewQuery(S3DB);
      q.SQL.Text := 'insert into BuildSheets (Title) values (:Title)';
      q.ParamByName('Title').AsString := ModelName;
      q.ExecSQL;
      ModelID := S3DB.GetInsertID;
      EndQuery(q);
      cboBuildSheetModel.AddItem(ModelName, I2O(ModelID));
      cboBuildSheetModel.ItemIndex := cboBuildSheetModel.Items.IndexOf(ModelName);
    end;
  end else begin
    ModelName := cboBuildSheetModel.Items[cboBuildSheetModel.ItemIndex];
    ModelID := O2I(cboBuildSheetModel.Items.Objects[cboBuildSheetModel.ItemIndex]);
  end;
  Order := TStringList.Create;
  Order.Text := rOrder;

  q := NewQuery(s3db);
  q.SQL.Text := 'delete from BuildSheetLists where BuildSheetID=:bsid';
  q.ParamByName('BSID').AsInteger := ModelID;
  q.ExecSQL;
  EndQuery(q);
  for x := 0 to Order.Count - 1 do begin
    Edit := TEdit(FindAnyComponent(ScrollBox1, 'txt' + SafeComponentName(Order[x])));
    q := NewQuery(S3DB);
    q.SQL.Text := 'insert into BuildSheetLists (BuildSheetID,ComponentName,ComponentCount) values (:bsid,:cn,:cc)';
    q.ParamByName('bsid').AsInteger := ModelID;
    q.ParamByName('cn').AsString := Edit.Name;
    q.ParamByName('cc').AsInteger := StrToInt(edit.Text);
    q.ExecSQL;
    S3DB.Transaction.Commit;
  end;
  Order.Free;
end;

procedure TBuildSheet.btnClearSheetClick (Sender: TObject);
var
  x: integer;
  y: integer;
begin
  StringGrid1.Clean(1, 1, StringGrid1.ColCount, StringGrid1.RowCount, [gzNormal]);
  cboBuildSheetModelChange(nil);
end;

procedure TBuildSheet.btnSaveSheetClick (Sender: TObject);
// And... away.. we go....
var
  q: TSQLQuery;
  BuildID: integer;
  BuildQR: string;
  CompQR: string;
  CompID: integer;
  CompName: string;
  CompTitle: string;
  BuildName: string;
  x: integer;
begin
  // First, let's figure out if the build is correct
  // The save button is protected from being run based on valid QRs being present
  // -- if no QR is present, text is not imported
  // -- If there are any QRs that aren't formatted correctly, the save button doesn't run

  BuildQR := StringGrid1.Cells[1, 1];
  q := NewQuery(s3db);
  q.SQL.Text := 'select BuildID from BuildList where BuildQR=:QR';
  q.ParamByName('QR').AsString := BuildQR;
  q.Open;
  BuildID := -1;
  if not q.EOF then begin // We have a result
    BuildID := q.FieldByName('BuildID').AsInteger;
  end;
  EndQuery(q);

  BuildQR := StringGrid1.Cells[1, 1];
  BuildName := StringGrid1.Cells[2, 1];
  if BuildID = -1 then begin
    // This appears to be a new build.  Throw it into the mix, get the new BuildID
    q := NewQuery(s3db);
    q.SQL.Text := 'insert into BuildList (BuildQR,BuildName) values (:QR,:BN)';
    q.ParamByName('QR').AsString := BuildQR;
    q.ParamByName('BN').AsString := BuildName;
    q.ExecSQL;
    BuildID := S3DB.GetInsertID;
    EndQuery(q);
  end else begin
    // We have an existing build, so we need to update it
    q := NewQuery(s3db);
    q.SQL.Text := 'update BuildList set BuildName=:bn where BuildID=:BI';
    q.ParamByName('bn').AsString := BuildName;
    q.ParamByName('bi').AsInteger := BuildID;
    q.ExecSQL;
    EndQuery(q);
  end;

  // Clearout the existing relationships
  q := NewQuery(s3db);
  q.SQL.Text := 'delete from BuildComponents where BuildID=:ID';
  q.ParamByName('ID').AsInteger := BuildID;
  q.ExecSQL;
  EndQuery(q);

  // Now we need to go down the rest of the list to check if the components exist, and do the update or insert.
  for x := 2 to StringGrid1.RowCount - 1 do begin
    CompName := StringGrid1.Cells[0, x];
    CompQR := StringGrid1.Cells[1, x];
    CompTitle := StringGrid1.Cells[2, x];
    if (CompQR <> '') and (trim(CompTitle) <> '') then begin
      q := NewQuery(s3db);
      q.SQL.Text := 'select DeviceID from Device_' + SafeComponentName(CompName) + ' where QRCode=:QR';
      q.ParamByName('QR').AsString := CompQR;
      q.Open;
      CompID := -1; // Set a default
      if not q.EOF then begin
        CompID := q.FieldByName('DeviceID').AsInteger;
      end;
      EndQuery(q);

      // Do we add or do we update?
      if CompID = -1 then begin // We add
        q := NewQuery(S3DB);
        q.SQL.Text := 'insert into Device_' + SafeComponentName(CompName) + ' (QRCode,Title) values (:QR,:Title)';
        q.ParamByName('QR').AsString := Trim(CompQR);
        q.ParamByName('Title').AsString := Trim(CompTitle);
        q.ExecSQL;
        CompID := S3DB.GetInsertID;
        EndQuery(q);
      end else begin // We update
        q := NewQuery(s3db);
        q.SQL.Text := 'update Device_' + SafeComponentName(CompName) + ' set QRCode=:QR, Title=:Title where DeviceID=:DevID';
        q.ParamByName('QR').AsString := CompQR;
        q.ParamByName('Title').AsString := trim(CompTitle);
        q.ParamByName('DevID').AsInteger := CompID;
        q.ExecSQL;
        EndQuery(q);
      end;

      // Now insert the new relationship
      q := NewQuery(s3db);
      q.SQL.Text := 'insert into BuildComponents (BuildID, Component, ComponentID) values (:BuildID,:Comp,:CompID)';
      q.ParamByName('BuildID').AsInteger := BuildID;
      q.ParamByName('Comp').AsString := SafeComponentName(CompName);
      q.ParamByName('CompID').AsInteger := CompID;
      q.ExecSQL;
      EndQuery(q);
    end;
  end;
  ModalResult := mrOk;
end;

procedure TBuildSheet.btnSearchClick (Sender: TObject);
begin
  //btnClearSheet;

end;

procedure TBuildSheet.btnDeleteModelClick (Sender: TObject);
var
  ModelID: integer;
  q: TSQLQuery;
begin
  if cboBuildSheetModel.ItemIndex > 0 then begin
    if Application.MessageBox('Are you sure you wish to delete this sheet?', 'Delete?', MB_YESNO + MB_ICONQUESTION) = ID_YES then begin
      ModelID := o2i(cboBuildSheetModel.Items.Objects[cboBuildSheetModel.ItemIndex]);
      q := NewQuery(S3DB);
      q.SQL.Text := 'delete from BuildSheets where BuildSheetID=:BSID';
      q.ParamByName('BSID').AsInteger := ModelID;
      q.ExecSQL;
      S3DB.Transaction.Commit;
      EndQuery(q);
    end;
  end;
end;

procedure TBuildSheet.ApplicationProperties1Idle (Sender: TObject; var Done: boolean);
var
  x: integer;
  sg: TStringGrid;
  ValidQRs: boolean;
  ContentCounts: integer;
  Value: string;
begin
  sg := StringGrid1;
  ValidQRs := True;
  ContentCounts := 0;
  for x := 1 to sg.RowCount - 1 do begin
    Value := trim(sg.Cells[1, x]);
    // Valid QR and non-empty companion description
    if (trim(sg.Cells[1, x]) <> '') and (trim(sg.Cells[2, x]) <> '') then begin
      if not ValidateQRCode(QRCode, Value) then begin
        ValidQRs := False;
      end;
      Inc(ContentCounts);
    end;
  end;
  btnSaveSheet.Enabled := (ContentCounts > 0) and ValidQRs;

end;

procedure TBuildSheet.btnExportFullClick (Sender: TObject);
var
  MaxLen: byte;
  x: integer;
  ExportList: TStringList;
  WorkLine: string;
  sg: TStringGrid;
  q:TSQLQuery;
  TempDB:TSQLite3Connection;
begin
  // Calculate the longest length of string in the Component list
  MaxLen := 0;
  for x := 1 to StringGrid1.RowCount - 1 do begin
    if length(StringGrid1.Cells[0, x]) > MaxLen then begin
      MaxLen := Length(stringgrid1.cells[0, x]);
    end;
  end;

end;

procedure TBuildSheet.btnExportNoQRClick (Sender: TObject);
var
  MaxLen: byte;
  x: integer;
  ExportList: TStringList;
  WorkLine: string;
  sg: TStringGrid;
begin
  // Calculate the longest length of string in the Component list
  MaxLen := 0;
  for x := 1 to StringGrid1.RowCount - 1 do begin
    if length(StringGrid1.Cells[0, x]) > MaxLen then begin
      MaxLen := Length(stringgrid1.cells[0, x]);
    end;
  end;

  ExportList := TStringList.Create;
  sg := StringGrid1;
  for x := 1 to StringGrid1.RowCount - 1 do begin
    if trim(sg.cells[1, x]) <> '' then begin
      if sg.cells[0, x] = sg.cells[0, x - 1] then begin
        WorkLine := Space(MaxLen);
      end else begin
        WorkLine := copy(trim(sg.cells[0, x]) + Space(MaxLen), 1, MaxLen);
      end;

      WorkLine := WorkLine + sg.cells[2, x];
      ExportList.Add(WorkLine);
    end;
  end;
  Clipboard.AsText := ExportList.Text;
  ExportList.Free;
end;

procedure TBuildSheet.btnRenameModelClick (Sender: TObject);
var
  OldModelName: string;
  NewModelName: string;
  ModelID: integer;
  q: TSQLQuery;
begin
  if cboBuildSheetModel.ItemIndex > 0 then begin
    OldModelName := trim(cboBuildSheetModel.Items[cboBuildSheetModel.ItemIndex]);
    ModelID := o2i(cboBuildSheetModel.Items.Objects[cboBuildSheetModel.ItemIndex]);
    NewModelName := trim(InputBox('Model Name', 'Enter the new model name:', OldModelName));
    if (NewModelName <> OldModelName) and (NewModelName <> '') then begin
      q := NewQuery(S3DB);
      q.SQL.Text := 'update BuildSheets set Title=:Title where BuildSheetID=:BSID';
      q.ParamByName('Title').AsString := NewModelName;
      q.ParamByName('BSID').AsInteger := ModelID;
      q.ExecSQL;
      EndQuery(q);
      cboBuildSheetModel.Items[cboBuildSheetModel.ItemIndex] := NewModelName;
    end;
  end;

end;

procedure TBuildSheet.FormDestroy (Sender: TObject);
var
  x: integer;
begin
  for x := 0 to CompsToDelete.Count - 1 do begin
    if TControl(CompsToDelete[x]) is TLabel then begin
      tlabel(CompsToDelete[x]).Free;
    end else if TControl(CompsToDelete[x]) is TEdit then begin
      tedit(CompsToDelete[x]).Free;
    end;
  end;
  CompsToDelete.Free;
end;

procedure TBuildSheet.FormResize (Sender: TObject);
begin

end;

procedure TBuildSheet.gbBuildSheetsResize (Sender: TObject);
var
  SizeTo: integer;
begin
  SizeTo := (Panel1.ClientWidth - 10) div 3;
  btnDeleteModel.ClientWidth := SizeTo;
  btnSaveModel.ClientWidth := SizeTo;
  btnRenameModel.ClientWidth := SizeTo;
end;

procedure TBuildSheet.StringGrid1SetEditText (Sender: TObject; ACol, ARow: integer; const Value: string);
var
  q: TSQLQuery;
  BSQ: TSQLQuery; // Build Sheet Query
  CSQ: TSQLQuery; // Component SQL Query
  sg: TStringGrid;
  x: integer;
  BuildID: integer;
  Order: TStringList;
  SafeOrder: TStringList;
  CompCountInBuild: integer;
  SafeName: string;
  FullName: string;
  DumbConnection: TSQLite3Connection;
begin
  sg := TStringGrid(Sender);
  if (ACol = 1) and (ARow = 1) and ValidateQRCode(QRCode, trim(Value)) then begin
    // See if we've got a build to pull from
    q := NewQuery(S3DB);
    q.SQL.Text := 'select BuildID from BuildList where BuildQR=:QR';
    q.ParamByName('QR').AsString := trim(sg.Cells[acol, arow]);
    q.Open;
    BuildID := -1;
    if not q.EOF then begin
      BuildID := q.FieldByName('BuildID').AsInteger;
    end;
    q.Close;
    EndQuery(q);
    if BuildID <> -1 then begin
      // WE'VE GOT ONE....
      // First, we need to find out how many actual components are assigned to the build.
      q := NewQuery(S3DB);
      q.SQL.Text := 'select count(*) CompCount from BuildComponents where BuildID=:BuildID';
      q.ParamByName('BuildID').AsInteger := BuildID;
      q.Open;
      CompCountInBuild := q.FieldByName('CompCount').AsInteger;
      q.Close;
      EndQuery(q);
      sg.RowCount := CompCountInBuild + 2; // +1 for the header, and +1 for the Build Name

      // We need to figure out how to associate the component safe names to full names
      // The BuildComponents table stores the component types as safe names, while
      // The Order uses full names
      // So we'll build another stringlist and do a 1:1 comparison
      // - SafeOrder will be able to poke the Device_ tables while Order will be able to deal with StringGrid fields
      //   and we can map between the two types of data

      Order := TStringList.Create;
      Order.Text := rOrder;

      SafeOrder := TStringList.Create;
      for x := 0 to Order.Count - 1 do begin
        SafeOrder.Add(SafeComponentName(Order[x]));
      end;

      // Now let's start tossing data into the WorkSheet
      // First, let's specifically pull the build name
      q := NewQuery(S3DB);
      q.SQL.Text := 'select BuildQR,BuildName from BuildList where BuildID=:BuildID';
      q.ParamByName('BuildID').AsInteger := BuildID;
      q.Open;
      sg.Cells[0, 1] := 'Build Name';
      sg.Cells[1, 1] := q.FieldByName('BuildQR').AsString;
      sg.cells[2, 1] := q.FieldByName('BuildName').AsString;
      EndQuery(q);

      OpenDB('ComputerDatabase.sqlite3', DumbConnection);

      BSQ := NewQuery(DumbConnection);
      bsq.SQL.Text := 'select * from BuildComponents where BuildID=:BuildID';
      bsq.ParamByName('BuildID').AsInteger := BuildID;
      bsq.Open;
      x := 2; // Start on row 2 since Build Name lives on 1
      while not BSQ.EOF do begin
        SafeName := trim(BSQ.FieldByName('Component').AsString);
        FullName := Order[SafeOrder.IndexOf(SafeName)];
        sg.Cells[0, x] := FullName;

        // Now we need to pull the component information
        CSQ := NewQuery(S3DB);
        csq.SQL.Text := 'select QRCode,Title from Device_' + SafeName + ' where DeviceID=:CompID';
        csq.ParamByName('CompID').AsInteger := bsq.FieldByName('ComponentID').AsInteger;
        csq.Open;
        if not csq.EOF then begin
          sg.Cells[1, x] := CSQ.FieldByName('QRCode').AsString;
          sg.Cells[2, x] := CSQ.FieldByName('Title').AsString;
        end;
        EndQuery(csq);

        //        BSQ.Active:=true;
        bsq.Next;
        Inc(x);
      end;
      EndQuery(bsq);
      Order.Free;
      SafeOrder.Free;
      CloseDB(DumbConnection);
      SaveSheet;
      CheckSheet;
      LoadSheet;
    end;

  end;
end;

procedure TBuildSheet.ValidateNumbers (Sender: TObject);
var
  Edit: TEdit;
  v, i, r: integer;
begin
  Edit := tedit(Sender);
  val(trim(Edit.Text), i, r);
  i := max(0, min(i, 9));
  Edit.Text := trim(IntToStr(i));
  // Take whatever we have in the grid, and put it into the RAM database
  SaveSheet;
  // Now let's check whats on the sheet
  CheckSheet;
  // Now put the proper contents ON the sheet.
  LoadSheet;
end;

procedure TBuildSheet.RepopulateForm;
begin
  CreateComponentCounters;
  RegenSheetModels;
  cboBuildSheetModelChange(nil);
end;

procedure TBuildSheet.RegenSheetModels;
var
  q: TSQLQuery;
  idx: integer;
begin
  q := NewQuery(s3db);
  q.SQL.Text := 'select BuildSheetID,Title from BuildSheets order by lower(Title)';
  q.Open;
  cboBuildSheetModel.Clear;
  cboBuildSheetModel.Items.Add('<<New Model>>');
  while not q.EOF do begin
    cboBuildSheetModel.AddItem(q.FieldByName('Title').AsString, i2o(q.FieldByName('BuildSheetID').AsInteger));
    q.Next;
  end;
  EndQuery(q);
  idx := -1;
  idx := IfThen(cboBuildSheetModel.Items.Count > 1, 1, 0);
  cboBuildSheetModel.ItemIndex := idx;
end;

procedure TBuildSheet.CreateComponentCounters;
var
  Order: TStringList;
  CompLabel: TLabel;
  CompCounter: TEdit;
  x: integer;
begin
  Order := TStringList.Create;
  Order.Text := rOrder;

  Order.Insert(0, 'Build Item');

  for x := 0 to Order.Count - 1 do begin
    CompLabel := TLabel.Create(ScrollBox1);
    CompsToDelete.Add(TObject(CompLabel));
    CompLabel.Caption := Order[x];
    CompLabel.Name := 'lbl' + SafeComponentName(Order[x]);
    CompLabel.Top := 5 + x * 20;
    CompLabel.Left := 25;
    CompLabel.Parent := ScrollBox1;

    // Don't create a Build List edit -- Can only be one, and that'll be forced to render
    CompCounter := TEdit.Create(ScrollBox1);
    CompsToDelete.Add(TObject(CompCounter));
    CompCounter.Name := 'txt' + SafeComponentName(Order[x]);
    CompCounter.Left := 5;
    CompCounter.Width := 20;
    CompCounter.Top := 3 + x * 20;
    CompCounter.Text := '0';
    CompCounter.Parent := ScrollBox1;
    if x = 0 then begin
      CompCounter.ReadOnly := True;
      CompCounter.ParentColor := True;
      CompCounter.Font.Color := clBtnShadow;
      CompCounter.Text := '1';
    end else begin
      CompCounter.OnExit := @ValidateNumbers;
    end;
  end;

  Order.Free;
end;

procedure TBuildSheet.NewSheetDB;
begin
  OpenDB(':memory:', BuildSheetDB);
  BuildSheetDB.Params.Values['busy_timeout'] := '5000';
  // Yes, I know, :MEMORY:, but, for debugging, could be using a file on the filesystem, so, throwing this technically no-op call in.
  BuildSheetDB.ExecuteDirect('drop table if exists WorkSheet');
  BuildSheetDB.ExecuteDirect('create table WorkSheet (RowNum Integer, GroupOrder Integer,  Component Text, QRCode Text, Title Text)');
  BuildSheetDB.Transaction.Commit;
end;

procedure TBuildSheet.SaveSheet;
var
  x: integer;
  q: TSQLQuery;
  BuildRowString: array of string;
begin
  NewSheetDB;

  // Is the cell C,R 0,1 named "Build Name"? -- If it isn't, insert it.
  if StringGrid1.Cells[0, 1] <> 'Build Name' then begin
    BuildRowString := ['Build Name', '', ''];
    StringGrid1.InsertRowWithValues(1, BuildRowString);
  end;

  q := NewQuery(BuildSheetDB);
  for x := 1 to StringGrid1.RowCount - 1 do begin
    q.SQL.Text := 'insert into WorkSheet (RowNum, Component, QRCode, Title) values (:RowNum,:Comp,:QR,:Title)';
    q.ParamByName('RowNum').AsInteger := x;
    q.ParamByName('Comp').AsString := trim(StringGrid1.Cells[0, x]);
    q.ParamByName('QR').AsString := trim(StringGrid1.Cells[1, x]);
    q.ParamByName('Title').AsString := trim(StringGrid1.Cells[2, x]);
    q.ExecSQL;
    BuildSheetDB.Transaction.Commit;
  end;
  EndQuery(q);

end;

procedure TBuildSheet.CheckSheet;
var
  q: TSQLQuery;
  x: integer;
  s: string;
  CurrentCompCount: integer;
  RequestedCompCount: integer;
  DeltaCompCount: integer;
  Order: TStringList;
  Edit: TEdit;
  BuildRowString: array of string;
begin
  (*
  This routine is going to be checking to see if we have the correct number of components listed on the sheet.

  Procedure
  - Go through all the components on the GroupBox that are tEdits
  - Figure out what component we're modifying based on its matching labels caption
  - Count the number of existing items in the stringgrid that maches the labels caption
  - If there is a negative delta, then we need to delete items
  - If there is a positive delta, then we need to add items
  - In either case, we work from bottom up
  *)

  Order := TStringList.Create;
  Order.Text := rOrder;

  // Clear the garbage
  BuildSheetDB.ExecuteDirect('delete from WorkSheet where Component='''' or Component is null');
  BuildSheetDB.Transaction.Commit;
  // Start going through the list of changes
  for x := 0 to Order.Count - 1 do begin
    q := NewQuery(BuildSheetDB);
    q.SQL.Text := 'select count(Component) CompCount from WorkSheet where Component=:CompName';
    q.ParamByName('CompName').AsString := Order[x];
    q.Open;
    CurrentCompCount := q.FieldByName('CompCount').AsInteger;
    q.Close;
    Edit := tedit(FindAnyComponent(ScrollBox1, 'txt' + SafeComponentName(Order[x])));
    RequestedCompCount := StrToInt(Edit.Text);
    DeltaCompCount := CurrentCompCount - RequestedCompCount;
    // No-Op if there's no change
    // There's more components than we've requested, so need to delete
    if DeltaCompCount > 0 then begin
      q := NewQuery(BuildSheetDB);
      s := 'delete from WorkSheet where Component=:CompName and (QRCode is null or QRCode='''') and (Title is null or Title='''')';
      q.SQL.Text := s;
      q.ParamByName('CompName').AsString := Order[x];
      q.ExecSQL;
      EndQuery(q);
      // We need to requery as "limit" isn't built in for delete statements by default in SQLite3 apparently.
      // -- Side notes; the perk is if we have 5 RAM Stick entries with content and we reduce the count to 3, the old data still sticks around.
      q := NewQuery(BuildSheetDB);
      q.SQL.Text := 'select count(Component) CompCount from WorkSheet where Component=:CompName';
      q.ParamByName('CompName').AsString := Order[x];
      q.Open;
      CurrentCompCount := q.FieldByName('CompCount').AsInteger;
      q.Close;
      DeltaCompCount := CurrentCompCount - RequestedCompCount;
    end;
    if DeltaCompCount < 0 then begin
      q := NewQuery(BuildSheetDB);
      q.SQL.Text := 'insert into WorkSheet (Component, GroupOrder, QRCode, Title) values (:CompName,:GroupOrder, :QRCode,:Title)';
      q.ParamByName('CompName').AsString := Order[x];
      q.ParamByName('GroupOrder').AsInteger := x;
      q.ParamByName('QRCode').AsString := '';
      q.ParamByName('Title').AsString := '';
      DeltaCompCount := Abs(DeltaCompCount);
      while DeltaCompCount > 0 do begin
        q.ExecSQL;
        BuildSheetDB.Transaction.Commit;
        Dec(DeltaCompCount);
      end;
      EndQuery(q);
    end;
    // Now set the group orders
    q := NewQuery(BuildSheetDB);
    q.SQL.Text := 'update WorkSheet set GroupOrder=:GO where Component=:Component';
    q.ParamByName('Component').AsString := Order[x];
    q.ParamByName('GO').AsInteger := x + 1;
    q.ExecSQL;
    BuildSheetDB.Transaction.Commit;
  end;
  // Put the Build Name line at the top of the list, always
  q := NewQuery(BuildSheetDB);
  q.SQL.Text := 'update WorkSheet set GroupOrder=:GO where Component=:Component';
  q.ParamByName('Component').AsString := 'Build Name';
  q.ParamByName('GO').AsInteger := 0;
  q.ExecSQL;
  BuildSheetDB.Transaction.Commit;

  // Set a high integer value to any rows that were not entered with a row number -- Saves from odd "NULL" problems in the DB I encountered.
  q := NewQuery(BuildSheetDB);
  q.SQL.Text := 'update WorkSheet set RowNum=:RN where RowNum is null';
  q.ParamByName('RN').AsInteger := 65535;
  q.ExecSQL;
  BuildSheetDB.Transaction.Commit;
  Order.Free;

end;

procedure TBuildSheet.LoadSheet;
var
  q: TSQLQuery;
  WorkingRows: integer;
  CurrentRow: integer;
begin
  q := NewQuery(BuildSheetDB);
  q.SQL.Text := 'select count(*) RecordCount from WorkSheet';
  q.Open;
  WorkingRows := q.FieldByName('RecordCount').AsInteger;
  q.Close;
  EndQuery(q);

  // For whatever reason, q.recordcount wasn't giving the right number of rows back.  Not sure if one has to go to last then first, but whatever.  It's a small table.
  q := NewQuery(BuildSheetDB);
  q.SQL.Text := 'select * from WorkSheet order by GroupOrder, QRCode = '''' , RowNum,QRCode';
  q.Open;
  StringGrid1.RowCount := WorkingRows + 1;
  CurrentRow := 1;
  while not q.EOF do begin
    StringGrid1.Cells[0, CurrentRow] := q.FieldByName('Component').AsString;
    StringGrid1.Cells[1, CurrentRow] := q.FieldByName('QRCode').AsString;
    StringGrid1.Cells[2, CurrentRow] := q.FieldByName('Title').AsString;
    Inc(CurrentRow);
    q.Next;
  end;
  q.Close;
  EndQuery(q);
  CloseDB(BuildSheetDB);
  StringGrid1.AutoSizeColumn(0);
  StringGrid1.Col := 1;
  StringGrid1.Row := 1;
end;

function TBuildSheet.rOrder: string;
var
  ini: TIniFile;
begin
  if not assigned(lOrder) then begin
    ini := TIniFile.Create('Structure.ini');
    lOrder := TStringList.Create;
    ini.ReadSection('Order', lOrder);
    ini.Free;
  end;
  Result := lOrder.Text;
end;

function TBuildSheet.rSafeOrder: string;
var
  x: integer;
begin
  if not assigned(lSafeOrder) then begin
    lSafeOrder := TStringList.Create;
    lSafeOrder.Text := rOrder;
    for x := 0 to lSafeOrder.Count - 1 do begin
      lSafeOrder[x] := SafeComponentName(lSafeOrder[x]);
    end;
  end;
  Result := lSafeOrder.Text;
end;

initialization

finalization

end.
