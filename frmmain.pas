unit frmMain;
{$mode objfpc}{$H+}

interface

uses
  Classes,SysUtils,Forms,Controls,Graphics,Dialogs,Menus,ComCtrls,StdCtrls,
  ExtCtrls,ExtendedTabControls,SynEdit,RTTICtrls,LCLType,Buttons,ColorBox,Spin,
  RegExpr,SQLite3Conn,SQLite3,process,SQLDB;

type
  TQRType = (QRCode, QRURL, QRPhoneNumber);
  TQRTypes = set of TQRType;

  { TForm1 }

  TForm1 = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    gbCompList1: TGroupBox;
    gbCompStats1: TGroupBox;
    lbBuildList: TListBox;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem16: TMenuItem;
    MenuItem17: TMenuItem;
    MenuItem18: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem20: TMenuItem;
    MenuItem21: TMenuItem;
    MenuItem22: TMenuItem;
    MenuItem23: TMenuItem;
    MenuItem24: TMenuItem;
    MenuItem25: TMenuItem;
    MenuItem26: TMenuItem;
    mnuResetManifest: TMenuItem;
    mnuAddToBuildManifest: TMenuItem;
    PageControl2: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    sbSystemBuildSpecs: TScrollBox;
    sbSystemBuildSpecs1: TScrollBox;
    Separator2: TMenuItem;
    MenuItem8: TMenuItem;
    mnuAddBuild: TMenuItem;
    mnuDeleteBuild: TMenuItem;
    mnuBuildList: TMenuItem;
    PageControl1: TPageControl;
    Splitter1: TSplitter;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    tsBuildSheet: TTabSheet;
    procedure ApplicationProperties1Idle (Sender: TObject; var Done: boolean);
    procedure FormActivate (Sender: TObject);
    procedure FormCreate (Sender: TObject);
    procedure FormDestroy (Sender: TObject);
    procedure lbBuildListClick (Sender: TObject);
    procedure Memo1Exit (Sender: TObject);
    procedure mnuResetManifestClick (Sender: TObject);
    procedure mnuAddToBuildManifestClick (Sender: TObject);
    procedure MenuItem8Click (Sender: TObject);
    procedure mnuAddBuildClick (Sender: TObject);
    procedure mnuBuildListClick (Sender: TObject);
    procedure mnuDeleteBuildClick (Sender: TObject);
    procedure PageControl1Change (Sender: TObject);
    procedure MenuParentClick (Sender: TObject);
    procedure ListBoxClick (Sender: TObject);
    procedure AddMenuClick (Sender: TObject);
  private
    procedure CreateTab (ComponentName: string);

    procedure RefreshBuildList;
    procedure RenderComponentGroups;
    procedure GenerateMenuSystem;
    procedure CleanupDynamicMenus;
    procedure LoadBuildDetails;
    procedure LoadDataIntoListBox (ListBox: TListBox; const TableName: string);

    function SanitizeComponentName (const S: string): string;
    procedure AddSubMenu (ParentMenu: TMenuItem; const SubCaption: string; TagValue: integer);
    procedure MenuItemClick (Sender: TObject);
    procedure PopulateSpecsPane (DeviceID: integer);
    procedure PopulateSpecsPane (DeviceID: integer; const TabShortName: string);
    function PromptAndValidateQRCodeAndTitle (TabCaption: string; QRTypes: TQRType; out QRString, Title: string): boolean;
    function ValidateQRCode (QRType: TQRType; QRString: string): boolean;
    function HandleBuildComponentAction (Mode, ShortName: string; OptionalDeviceID: integer = -1): boolean;
    function AddBuildComponent (ShortName: string): boolean;
    function DeleteBuildComponent (ShortName: string): boolean;
  public

  end;

var
  Form1: TForm1;
  GlobalComponentList: TStringList;

implementation

uses IniFiles, SimpleSQLite3, DatabaseManager, MiscFunctions, TabGrouping, ComponentDetails;

  {$R *.lfm}

  { TForm1 }
var
  MenuToggleList: TStringList;
  ListOfCustomObjects: TStringList;

const
  EditHeight = 25;


function FindAnyComponent (Root: TComponent; const Name: string): TComponent;
var
  i: integer;
  Found: TComponent;
begin
  if Root.Name = Name then begin
    Exit(Root);
  end;

  for i := 0 to Root.ComponentCount - 1 do begin
    Found := FindAnyComponent(Root.Components[i], Name);
    if Assigned(Found) then begin
      Exit(Found);
    end;
  end;

  Result := nil;
end;

function IsDynamicTab (const TabCaption: string): boolean;
var
  Ini: TIniFile;
  DynamicTabs: TStringList;
  ResultFound: boolean;
begin
  DynamicTabs := TStringList.Create;
  Ini := TIniFile.Create('Structure.ini');
  try
    Ini.ReadSection('ORDER', DynamicTabs);
    ResultFound := DynamicTabs.IndexOf(TabCaption) <> -1;
  finally
    Ini.Free;
    DynamicTabs.Free;
  end;
  Result := ResultFound;
end;

procedure DeleteChildObjects (Sender: TComponent);
var
  i, CountBefore: integer;
  ControlList: array of TControl;
begin
  // Code generated in this function by AI due to author being an I-D-Ten-T.
  if not (Sender is TWinControl) then begin
    Exit;
  end;

  CountBefore := TWinControl(Sender).ControlCount;

  if CountBefore = 0 then begin
    Exit;
  end;

  SetLength(ControlList, CountBefore);
  for i := 0 to CountBefore - 1 do begin
    ControlList[i] := TWinControl(Sender).Controls[i];
  end;

  // Now delete from stored list
  for i := High(ControlList) downto Low(ControlList) do begin
    if ControlList[i] is TGroupBox then begin
      DeleteChildObjects(ControlList[i]);
    end; // Recursively delete child controls
    ControlList[i].Free;
  end;

  SetLength(ControlList, 0);

end;

procedure TForm1.MenuItem8Click (Sender: TObject);
var
  CurrentItem: TObject;
begin
  CurrentItem := nil;
  if lbBuildList.ItemIndex <> -1 then begin
    CurrentItem := lbBuildList.Items.Objects[lbBuildList.ItemIndex];
  end;
  lbBuildList.SetFocus;
  RefreshBuildList;
  if CurrentItem <> nil then begin
    lbBuildList.ItemIndex := lbBuildList.Items.IndexOfObject(CurrentItem);
  end;
  if lbBuildList.ItemIndex <> -1 then begin
    lbBuildListClick(nil);
  end;
end;

function TForm1.PromptAndValidateQRCodeAndTitle (TabCaption: string; QRTypes: TQRType; out QRString, Title: string): boolean;
var
  BuildQuestions: array[0..1] of string;
  BuildAnswers: array[0..1] of string;
  Valid, Cancelled, ReversedValid: boolean;
  Temp: string;
begin
  Result := False;
  Cancelled := False;
  Valid := False;

  BuildQuestions[0] := 'Enter Title/Description';
  BuildQuestions[1] := 'Enter QRCode (Format: YYMM-NNN):';

  Title := '';
  QRString := '';

  repeat
    BuildAnswers[0] := Trim(Title);
    BuildAnswers[1] := Trim(QRString);

    if InputQuery('Add ' + TabCaption, BuildQuestions, BuildAnswers) then begin
      Title := Trim(BuildAnswers[0]);
      QRString := Trim(BuildAnswers[1]);
      Valid := ValidateQRCode(QRCode, QRString);

      if not Valid then begin
        ReversedValid := ValidateQRCode(QRCode, Title);

        if ReversedValid then begin
          if Application.MessageBox(
            PChar('It looks like you may have reversed the QRCode and Title fields.' + sLineBreak +
            'Title: ' + Title + sLineBreak +
            'QRCode: ' + QRString + sLineBreak + sLineBreak +
            'Would you like to swap them and continue?'),
            'Possible Input Reversal',
            MB_YESNO or MB_ICONQUESTION
            ) = idYes then begin
            Temp := QRString;
            QRString := Title;
            Title := Temp;
            Valid := True;
          end else begin
            Application.MessageBox('Please correct the input format.', 'Format Error', MB_OK);
          end;
        end else begin
          Application.MessageBox('Invalid QRCode format. Must be YYMM-NNN.', 'Format Error', MB_OK);
        end;
      end;
    end else begin
      Cancelled := True;
    end;
  until Valid or Cancelled;

  if Valid then begin
    Result := True;
  end;
end;

function TForm1.ValidateQRCode (QRType: TQRType; QRString: string): boolean;
begin
  Result := False;

  case QRType of
    QRCode: begin
      Result := ExecRegExpr('^[0-9]{4}-[0-9]{3}$', QRString);
    end;
    QRURL: begin
      // TODO: Implement URL validation
      Result := True;
    end;
    QRPhoneNumber: begin
      // TODO: Implement phone number validation
      Result := True;
    end;
  end;
end;

function TForm1.HandleBuildComponentAction (Mode, ShortName: string; OptionalDeviceID: integer = -1): boolean;
begin
  Result := False;

  if Mode = 'Add' then begin
    Result := AddBuildComponent(ShortName);
  end else if Mode = 'Edit' then begin
    // Edit functionality not yet implemented
  end else if Mode = 'Delete' then begin
    Result := DeleteBuildComponent(ShortName);
  end;
end;

procedure TForm1.mnuAddBuildClick (Sender: TObject);
var
  BuildQuestions: array[0..1] of string;
  BuildAnswers: array[0..1] of string;
  x: integer;
  ValidInput: boolean;
  ValidError: string;
  Query: TSQLQuery;
  NewBuildID: integer;
  Answer: string;
begin
  BuildQuestions[0] := 'Build Name';
  BuildQuestions[1] := 'Build QR Code [yymm-xxx]';
  BuildAnswers[0] := '';
  BuildAnswers[1] := '';
  ValidInput := True;
  if InputQuery('Build Info', BuildQuestions, BuildAnswers) then begin
    for x := 0 to 1 do begin
      BuildAnswers[x] := trim(BuildAnswers[x]);
      if BuildAnswers[x] = '' then begin
        ValidError := 'Cannot use Blank Fields';
        ValidInput := False;
      end;
    end;
    if ValidInput then begin
      Answer := trim(BuildAnswers[1]);
      if not ExecRegExpr('^\d{4}-\d{3}$', Answer) then begin
        ValidInput := False;
        ValidError := 'Invalid format for QR code.  Must be ####-###, where the format is [Year][Year][Month][Month]-{Sequence}';
      end;
    end;
    if not ValidInput then begin
      Application.MessageBox(PChar(ValidError), 'Error', MB_OK + MB_ICONERROR);
    end;
  end else begin
    ValidInput := False;
  end;

  if ValidInput then begin
    if not S3DB.Transaction.Active then begin
      S3DB.Transaction.StartTransaction;
    end;  // Ensure transaction is active

    Query := NewQuery(S3DB);
    Query.SQL.Text := 'insert into BuildList (BuildQR,BuildName) values (:BuildQR, :BuildName);';
    Query.Params.ParamByName('BuildName').AsString := BuildAnswers[0];
    Query.Params.ParamByName('BuildQR').AsString := BuildAnswers[1];

    try
      Query.ExecSQL;

      NewBuildID := S3DB.GetInsertID;
      if S3DB.Transaction.Active then begin
        S3DB.Transaction.Commit;
      end;
    except
      on E: Exception do begin
        if S3DB.Transaction.Active then begin
          S3DB.Transaction.Rollback;
        end;  // Rollback on error to prevent locks
        raise; // Re-raise exception to see error in Lazarus debugger
      end;
    end;

    Query.Close;
    Query.Free;

    RefreshBuildList;
    lbBuildList.ItemIndex := lbBuildList.Items.IndexOfObject(i2o(NewBuildID));
    lbBuildListClick(nil);
  end;

end;

procedure TForm1.mnuBuildListClick (Sender: TObject);
begin
  mnuDeleteBuild.Enabled := lbBuildList.ItemIndex <> -1;

end;

procedure TForm1.mnuDeleteBuildClick (Sender: TObject);
var
  idx: integer;
  q: TSQLQuery;
begin
  idx := ListObject(lbBuildList);
  if BuildExists(S3DB, idx) and (Application.MessageBox('Are you sure you wish to delete this item?', 'Delete', MB_YESNO + MB_ICONEXCLAMATION) = ID_YES) then begin
    q := NewQuery(S3DB);
    q.SQL.Text := 'delete from BuildList where buildid=:buildid';
    q.Params.ParamValues['buildid'] := idx;
    q.ExecSQL;
    EndQuery(q);
    RefreshBuildList;
  end;
end;

procedure TForm1.FormCreate (Sender: TObject);
var
  x, y: integer;
  gb: TGroupBox;
  ffc: TObject;
  MenuSubject: TMenuItem;
  MenuName: string;
  NewSheetName: string;
begin
  x := 0;
  // AddObject(Name of Tab Sheet, tobject(Name of Menu))
  MenuToggleList := TStringList.Create;
  GenerateMenuSystem;
  while x < MainMenu1.Items.Count - 1 do begin
    MenuSubject := TMenuItem(MainMenu1.Items[x]);
    MenuName := MenuSubject.Name;
    if UpperCase(RightStr(MenuName, 2)) = '_T' then begin
      CreateTab(MenuSubject.Caption);
      NewSheetName := 'ts' + NoSpaces(MenuSubject.Caption);
      ffc := FindAnyComponent(Form1, NewSheetName);
      if ffc <> nil then begin
        MenuToggleList.AddObject(tMenuItem(ffc).Name, TObject(MenuSubject));
      end;
    end;
    Inc(x);
  end;
  PageControl1.ActivePageIndex := 0;
  PageControl1Change(nil);
  ListOfCustomObjects := TStringList.Create;

  DeleteChildObjects(sbSystemBuildSpecs);
  RefreshBuildList;

end;

procedure TForm1.ApplicationProperties1Idle (Sender: TObject; var Done: boolean);
begin
  Memo1.Enabled := lbBuildList.ItemIndex <> -1;
  if (lbBuildList.ItemIndex = -1) and (Memo1.Text <> '') then begin
    Memo1.Text := '';
  end;
end;

procedure TForm1.FormActivate (Sender: TObject);
begin

end;

procedure TForm1.FormDestroy (Sender: TObject);
begin
  // Clean up everything in the tab sheets
  while ListOfCustomObjects.Count > 0 do begin
  end;
  MenuToggleList.Free;

  DeleteChildObjects(TComponent(sbSystemBuildSpecs));
  CleanupDynamicMenus;
end;

procedure TForm1.lbBuildListClick (Sender: TObject);
var
  QRForBuild: string;
begin
  sbSystemBuildSpecs.BeginUpdateBounds;
  DeleteChildObjects(TComponent(sbSystemBuildSpecs));
  RenderComponentGroups;
  sbSystemBuildSpecs.EndUpdateBounds;
  LoadBuildDetails;
end;

procedure TForm1.Memo1Exit (Sender: TObject);
var
  q: TSQLQuery;
begin
  if lbBuildList.ItemIndex <> -1 then begin
    if Memo1.Modified then begin
      q := NewQuery(S3DB);
      q.SQL.Text := 'update BuildList set Notes=:Notes where BuildID=:BuildID';
      q.Params.ParamValues['Notes'] := trim(Memo1.Text);
      q.Params.ParamValues['BuildID'] := ListObject(lbBuildList);
      q.ExecSQL;
      EndQuery(q);
    end;
    Memo1.Modified := False;
  end;
end;

procedure TForm1.mnuResetManifestClick (Sender: TObject);
begin
  // This will wipe out ALL components to this build
  // Use of this will not delete components, just "unassociate" them to a build
end;

procedure TForm1.mnuAddToBuildManifestClick (Sender: TObject);
begin
  // This will pop up a dialog where the user can zap all the QR codes into a box
  // On submission, each QR will be added to the build ID
  // Duplicates are ignored
end;

procedure TForm1.PageControl1Change (Sender: TObject);
var
  x: integer;
  ActivePageName, TableName, ShortName: string;
  MenuItemCaption: string;
  MenuItem: TMenuItem;
  ListBox: TListBox;
  Ini: TIniFile;
  DynamicTab: boolean;
begin
  for x := 0 to MenuToggleList.Count - 1 do begin
    MenuItem := TMenuItem(MenuToggleList.Objects[x]);
    ActivePageName := PageControl1.ActivePage.Caption;
    MenuItemCaption := MenuItem.Caption;
    MenuItem.Visible := ActivePageName = MenuItemCaption;
  end;

  // Check if this is a dynamic tab by looking at INI or _T suffix
  DynamicTab := False;
  Ini := TIniFile.Create('Structure.ini');
  try
    DynamicTab := Ini.ValueExists('ORDER', ActivePageName);
  finally
    Ini.Free;
  end;

  if not DynamicTab then begin
    DynamicTab := PageControl1.ActivePage.Name.EndsWith('_T');
  end;

  // Skip processing if this is not a dynamic tab
  if not DynamicTab then begin
    Exit;
  end;

  // Get the table name (remove spaces from tab caption)
  ShortName := StringReplace(PageControl1.ActivePage.Caption, ' ', '', [rfReplaceAll]);
  TableName := 'Device_' + ShortName;

  // Find the ListBox in the correct group box within the active tab
  //  ListBox := tListbox(FindAnyComponent(PageControl1.ActivePage, ShortName));
  ListBox := TListBox(FindAnyComponent(PageControl1.ActivePage, 'lb' + ShortName + 'List'));

  if Assigned(ListBox) then begin
    LoadDataIntoListBox(ListBox, TableName);
  end else begin
    Application.MessageBox(PChar('ListBox not found for ' + TableName), 'Error', MB_OK);
  end;
end;

procedure TForm1.LoadDataIntoListBox (ListBox: TListBox; const TableName: string);
var
  Query: TSQLQuery;
  Line: string;
  ID: integer;
const
  BeginQRChar = '';
  EndQRChar = '- ';
begin
  ListBox.Clear; // Ensure the listbox is fully reset before repopulating

  Query := NewQuery(S3DB);
  try
    Query.SQL.Text := 'SELECT DeviceID, QRCode, Title FROM ' + TableName + ' ORDER BY upper(Title);';
    Query.Open;

    while not Query.EOF do begin
      Line := BeginQRChar + Query.FieldByName('QRCode').AsString + EndQRChar + Query.FieldByName('Title').AsString;
      ID := Query.FieldByName('DeviceID').AsInteger;
      ListBox.AddItem(Line, i2o(ID));
      Query.Next;
    end;

    EndQuery(Query);
  except
    on E: Exception do begin
      EndQuery(Query);
      raise;
    end;
  end;
end;

{$i func_CreateTab.inc}

procedure TForm1.ListBoxClick (Sender: TObject);
var
  lb: TListBox;
  ParentGroup: TGroupBox;
  ParentTab: TTabSheet;
  TabShortName: string;
  DeviceID: integer;
begin
  if not (Sender is TListBox) then begin
    Exit;
  end;
  lb := TListBox(Sender);

  // Get DeviceID from selected item
  DeviceID := ListObject(lb);
  if DeviceID = -1 then begin
    Exit;
  end;

  // Get the tab short name
  ParentGroup := TGroupBox(lb.Parent);
  ParentTab := TTabSheet(ParentGroup.Parent);
  TabShortName := StringReplace(ParentTab.Caption, ' ', '', [rfReplaceAll]);

  // Call general-purpose spec population logic
  PopulateSpecsPane(DeviceID, TabShortName);
end;

procedure TForm1.PopulateSpecsPane (DeviceID: integer; const TabShortName: string);
var
  Query: TSQLQuery;
  TabSheet: TTabSheet;
  SpecsGroup: TGroupBox;
  InfoScroll: TScrollBox;
  FieldIndex: integer;
  FieldName, ComponentName: string;
  EditField: TEdit;
begin
  // Locate the tab and specs scroll box
  TabSheet := PageControl1.FindChildControl('ts' + TabShortName) as TTabSheet;
  if not Assigned(TabSheet) then begin
    Exit;
  end;

  SpecsGroup := TabSheet.FindComponent('gb' + TabShortName + 'Specs') as TGroupBox;
  if not Assigned(SpecsGroup) then begin
    Exit;
  end;

  InfoScroll := SpecsGroup.FindComponent('sb' + TabShortName + 'InfoPanel') as TScrollBox;
  if not Assigned(InfoScroll) then begin
    Exit;
  end;

  // Run the query
  Query := NewQuery(S3DB);
  try
    Query.SQL.Text := 'SELECT * FROM Device_' + TabShortName + ' WHERE DeviceID = :id';
    Query.ParamByName('id').AsInteger := DeviceID;
    Query.Open;

    if not Query.EOF then begin
      for FieldIndex := 0 to Query.Fields.Count - 1 do begin
        FieldName := Query.Fields[FieldIndex].FieldName;

        // Skip internal fields if needed
        if FieldName = 'DeviceID' then begin
          Continue;
        end;

        ComponentName := TabShortName + '_' + FieldName;
        EditField := InfoScroll.FindComponent(ComponentName) as TEdit;
        if Assigned(EditField) then begin
          EditField.Text := Query.FieldByName(FieldName).AsString;
        end;
      end;
    end;
  finally
    EndQuery(Query);
  end;
end;

procedure TForm1.RefreshBuildList;
var
  Query: TSQLQuery;
  Line: string;
  ID: integer;
const
  BeginQRChar = '';
  EndQRChar = '- ';
begin
  query := NewQuery(s3db);
  sbSystemBuildSpecs.BeginUpdateBounds;
  try
    Query.SQL.Text := 'SELECT * from BuildList order by upper(BuildName);';
    Query.Open;
    lbBuildList.Clear;
    while not Query.EOF do begin
      Line := BeginQRChar + query.FieldByName('BuildQR').AsString + EndQRChar + query.FieldByName('BuildName').AsString;
      ID := query.FieldByName('BuildID').AsInteger;
      lbBuildList.AddItem(Line, i2o(ID));
      Query.Next;
    end;
  finally
    EndQuery(query);
  end;
  sbSystemBuildSpecs.EndUpdateBounds;
end;

procedure TForm1.RenderComponentGroups;
var
  x: integer;
  pnl: tGroupBox;
  mi: TMenuItem;
begin
  for x := 0 to MainMenu1.Items.Count - 1 do begin
    mi := TMenuItem(MainMenu1.Items[x]);
    if mi.Name.EndsWith('_T') then begin
      pnl := tGroupBox.Create(sbSystemBuildSpecs);
      pnl.Name := 'gbBuild_' + mi.Name;
      pnl.Caption := TMenuItem(MainMenu1.Items[x]).Caption;
      pnl.Align := alTop;
      pnl.Top := 65535;
      pnl.ClientHeight := 90;
      pnl.Visible := True;
      pnl.Parent := sbSystemBuildSpecs;
    end;
  end;
end;

function TForm1.SanitizeComponentName (const S: string): string;
var
  i: integer;
begin
  Result := '';
  for i := 1 to Length(S) do begin
    if S[i] in ['0'..'9', 'A'..'Z', 'a'..'z', '_'] then begin
      Result := Result + S[i];
    end else begin
      Result := Result + '_';
    end; // Replace invalid characters with underscores
  end;
end;

procedure TForm1.AddSubMenu (ParentMenu: TMenuItem; const SubCaption: string; TagValue: integer);
var
  SubMenu: TMenuItem;
begin
  SubMenu := TMenuItem.Create(ParentMenu);
  SubMenu.Caption := SubCaption;
  SubMenu.Name := SanitizeComponentName(ParentMenu.Name + '_' + SubCaption); // Ensure valid component name
  SubMenu.OnClick := @MenuItemClick;
  SubMenu.Tag := TagValue;
  ParentMenu.Add(SubMenu);
end;

// Handle submenu clicks
procedure TForm1.MenuItemClick (Sender: TObject);
var
  MenuAction, ParentCaption, ShortName, TableName: string;
  MenuItem, ParentItem: TMenuItem;
begin
  if not (Sender is TMenuItem) then begin
    Application.MessageBox('Invalid menu sender.', 'Error', MB_OK);
  end else begin
    MenuItem := TMenuItem(Sender);
    MenuAction := MenuItem.Caption;

    if Assigned(MenuItem.Parent) and (MenuItem.Parent is TMenuItem) then begin
      ParentItem := TMenuItem(MenuItem.Parent);
      ParentCaption := ParentItem.Caption;
      ShortName := StringReplace(ParentCaption, ' ', '', [rfReplaceAll]);
      TableName := 'Device_' + ShortName;

      if MenuAction = 'Add' then begin
        HandleBuildComponentAction('Add', ShortName);
        // AddBuildComponent(ShortName);
      end else if MenuAction = 'Edit' then begin
        // EditBuildComponent(ShortName);
      end else if MenuAction = 'Delete' then begin
        HandleBuildComponentAction('Delete', ShortName);
        // DeleteBuildComponent(ShortName);
      end else begin
        Application.MessageBox(PChar('Unknown action: ' + MenuAction), 'Error', MB_OK);
      end;
    end else begin
      Application.MessageBox('Parent menu not assigned for this action.', 'Error', MB_OK);
    end;
  end;
end;

procedure TForm1.GenerateMenuSystem;
var

  ini: TIniFile;
  Order: TStringList;
  x: integer;
  mnu: TMenuItem;
begin
  Order := TStringList.Create;
  ini := TIniFile.Create('Structure.ini');
  ini.ReadSection('Order', Order);
  for x := 0 to Order.Count - 1 do begin
    mnu := TMenuItem.Create(MainMenu1);
    mnu.Caption := Order[x];
    mnu.Name := 'mnu' + NoSpaces(Order[x]) + '_T';
    mnu.Visible := False;
    mnu.OnClick := @MenuParentClick;

    // Add common submenus
    AddSubMenu(mnu, 'Add', x);
    AddSubMenu(mnu, 'Delete', x);
    AddSubMenu(mnu, 'Edit', x);

    MainMenu1.Items.Insert(MainMenu1.Items.Count - 1, mnu);

  end;
  ini.Free;
  Order.Free;
  { TODO : Clean up the menus on shutdown }
end;

procedure TForm1.MenuParentClick (Sender: TObject);
var
  MenuItem: TMenuItem;
  TabSheet: TTabSheet;
  ListBox: TListBox;
  ShortName: string;
  i: integer;
begin
  if Sender is TMenuItem then begin
    MenuItem := TMenuItem(Sender);

    // Extract the tab name from the menu name
    ShortName := StringReplace(MenuItem.Caption, ' ', '', [rfReplaceAll]);

    // Find the corresponding tab
    TabSheet := nil;
    for i := 0 to PageControl1.PageCount - 1 do begin
      if PageControl1.Pages[i].Name = 'ts' + ShortName then begin
        TabSheet := PageControl1.Pages[i];
        Break;
      end;
    end;

    if Assigned(TabSheet) then begin
      // Find the ListBox within the correct GroupBox inside the Tab
      ListBox := tListbox(FindAnyComponent(TabSheet, ShortName));

      if Assigned(ListBox) then begin
        // Enable/Disable Delete & Edit based on ListBox selection
        for i := 0 to MenuItem.Count - 1 do begin
          if (MenuItem.Items[i].Caption = 'Delete') or (MenuItem.Items[i].Caption = 'Edit') then begin
            MenuItem.Items[i].Enabled := ListBox.ItemIndex <> -1;
          end;
        end;
      end;
    end;
  end;
end;

procedure TForm1.CleanupDynamicMenus;
var
  i, j: integer;
  MenuItem, SubMenuItem: TMenuItem;
begin
  // Iterate backwards to avoid index shifting while deleting
  for i := MainMenu1.Items.Count - 1 downto 0 do begin
    MenuItem := MainMenu1.Items[i];

    // Check if this menu item was dynamically created
    if MenuItem.Name.EndsWith('_T') then begin
      // Remove and free all sub-items first
      for j := MenuItem.Count - 1 downto 0 do begin
        SubMenuItem := MenuItem.Items[j];
        MenuItem.Delete(j); // Remove it from the parent
        SubMenuItem.Free;   // Free it from memory
      end;

      // Remove from main menu
      MainMenu1.Items.Delete(i);
      MenuItem.Free;
    end;
  end;
end;

procedure TForm1.LoadBuildDetails;
var
  q: TSQLQuery;
  BuildID: integer;
begin
  Memo1.Text := '';
  if lbBuildList.ItemIndex <> -1 then begin
    q := NewQuery(S3DB);
    q.SQL.Text := 'select Notes from BuildList where BuildID=:BuildID';
    q.Params.ParamValues['BuildID'] := o2i(lbBuildList.Items.Objects[lbBuildList.ItemIndex]);
    q.Open;
    q.First;
    if not q.EOF then begin
      Memo1.Text := q.FieldByName('Notes').AsString;
    end;
    q.Close;
  end;
  Memo1.Modified := False;
end;

procedure TForm1.PopulateSpecsPane (DeviceID: integer);
var
  Query: TSQLQuery;
  FieldName, FieldValue: string;
  YPos, i: integer;
  LabelField: TLabel;
  EditField: TEdit;
  ActiveTab: TTabSheet;
  StrippedTabName: string;
  SpecsGroup: TGroupBox;
  Ini: TIniFile;
  IsDynamicTab: boolean;
begin
  // Get the currently selected tab
  ActiveTab := PageControl1.ActivePage;
  if ActiveTab = nil then begin
    Exit;
  end;

  // Strip spaces from tab caption to match the expected naming convention
  StrippedTabName := StringReplace(ActiveTab.Caption, ' ', '', [rfReplaceAll]);

  // Check if this is a dynamic tab
  IsDynamicTab := False;
  Ini := TIniFile.Create('Structure.ini');
  try
    IsDynamicTab := Ini.ValueExists('ORDER', ActiveTab.Caption);
  finally
    Ini.Free;
  end;

  if not IsDynamicTab then begin
    IsDynamicTab := ActiveTab.Name.EndsWith('_T');
  end;

  // If it's not dynamic, exit (static tabs like "Build List" don't have specs)
  if not IsDynamicTab then begin
    Exit;
  end;

  // Find the dynamically created Specs group box in this tab
  SpecsGroup := TGroupBox(ActiveTab.FindComponent('gb' + StrippedTabName + 'Specs'));
  if SpecsGroup = nil then begin
    Exit;
  end;  // Prevent crashes if the component doesn’t exist

  // Clear previous fields in the Specs panel
  for i := SpecsGroup.ControlCount - 1 downto 0 do begin
    SpecsGroup.Controls[i].Free;
  end;

  // Query the database for this specific device
  Query := NewQuery(S3DB);
  try
    Query.SQL.Text := 'SELECT * FROM Device_' + StrippedTabName + ' WHERE DeviceID = :DeviceID';
    Query.ParamByName('DeviceID').AsInteger := DeviceID;
    Query.Open;

    if Query.RecordCount = 0 then begin
      Exit;
    end;

    YPos := 10;

    for i := 0 to Query.FieldCount - 1 do begin
      FieldName := Query.Fields[i].FieldName;
      FieldValue := Query.Fields[i].AsString;

      // Skip DeviceID (read-only)
      if FieldName = 'DeviceID' then begin
        Continue;
      end;

      // Create a label
      LabelField := TLabel.Create(SpecsGroup);
      LabelField.Parent := SpecsGroup;
      LabelField.Caption := FieldName + ':';
      LabelField.Top := YPos;
      LabelField.Left := 10;

      // Create an input field
      EditField := TEdit.Create(SpecsGroup);
      EditField.Parent := SpecsGroup;
      EditField.Text := FieldValue;
      EditField.Top := YPos;
      EditField.Left := 120;
      EditField.Width := 200;
      EditField.Name := 'edit_' + FieldName;

      YPos := YPos + EditHeight;
    end;

    Query.Close;
  finally
    EndQuery(Query);
  end;
end;

procedure TForm1.AddMenuClick (Sender: TObject);
var
  ActiveTab: TTabSheet;
  TabCaption, TabShortName, TableName, InsertSQL: string;
  Query: TSQLQuery;
  NewID: integer;
  lb: TListBox;
begin
  ActiveTab := PageControl1.ActivePage;
  TabCaption := ActiveTab.Caption;

  if IsDynamicTab(TabCaption) then begin
    TabShortName := StringReplace(TabCaption, ' ', '', [rfReplaceAll]);
    TableName := 'Device_' + TabShortName;

    // Insert default row (Title and QRCode are expected at minimum)
    InsertSQL := 'INSERT INTO ' + TableName + ' (QRCode, Title) VALUES (:qr, :title)';
    Query := NewQuery(S3DB);
    try
      Query.SQL.Text := InsertSQL;
      Query.ParamByName('qr').AsString := '';
      Query.ParamByName('title').AsString := 'New ' + TabCaption;
      Query.ExecSQL;
      S3DB.Transaction.Commit;
      Query.SQL.Text := 'SELECT last_insert_rowid() as NewID';
      Query.Open;
      NewID := Query.FieldByName('NewID').AsInteger;
    finally
      EndQuery(Query);
    end;

    // Find ListBox and add the new item
    lb := TListBox(FindComponent('lb' + TabShortName + 'List'));
    if Assigned(lb) then begin
      lb.AddItem(' - New ' + TabCaption, I2O(NewID));
      lb.ItemIndex := lb.Items.Count - 1;
      ListBoxClick(lb);
    end;
  end else begin
    Application.MessageBox('Add is only supported on dynamic tabs.', 'Unsupported', MB_OK);
  end;
end;

function TForm1.DeleteBuildComponent (ShortName: string): boolean;
var
  TableName, DeleteSQL: string;
  TabSheet: TTabSheet;
  ListBox: TListBox;
  Query: TSQLQuery;
  DeviceID: integer;
  i: integer;
begin
  Result := False;
  TableName := 'Device_' + ShortName;
  DeviceID := -1;

  for i := 0 to PageControl1.PageCount - 1 do begin
    TabSheet := PageControl1.Pages[i];
    if StringReplace(TabSheet.Caption, ' ', '', [rfReplaceAll]) = ShortName then begin
      ListBox := TListBox(FindAnyComponent(TabSheet, 'lb' + ShortName + 'List'));
      if Assigned(ListBox) and (ListBox.ItemIndex >= 0) then begin
        DeviceID := O2I(ListBox.Items.Objects[ListBox.ItemIndex]);

        if DeviceID > 0 then begin
          if Application.MessageBox(PChar('Are you sure you want to delete:' + sLineBreak + sLineBreak + ListBox.Items[ListBox.ItemIndex]), 'Confirm Deletion', MB_YESNO or MB_ICONQUESTION) = idYes then begin
            DeleteSQL := 'DELETE FROM ' + TableName + ' WHERE DeviceID = :DeviceID';
            Query := NewQuery(S3DB);
            try
              Query.SQL.Text := DeleteSQL;
              Query.Params.ParamByName('DeviceID').AsInteger := DeviceID;
              Query.ExecSQL;
              S3DB.Transaction.Commit;
            finally
              EndQuery(Query);
            end;

            LoadDataIntoListBox(ListBox, TableName);
            ListBox.ItemIndex := -1;

            Result := True;
          end;
        end;
      end;
    end;
  end;
end;

function TForm1.AddBuildComponent (ShortName: string): boolean;
var
  TableName, TabCaption, QRString, Title, InsertSQL: string;
  Query: TSQLQuery;
  TabSheet: TTabSheet;
  ListBox: TListBox;
  i, MatchIndex: integer;
begin
  Result := False;
  TableName := 'Device_' + ShortName;
  TabCaption := '';

  for i := 0 to PageControl1.PageCount - 1 do begin
    if StringReplace(PageControl1.Pages[i].Caption, ' ', '', [rfReplaceAll]) = ShortName then begin
      TabCaption := PageControl1.Pages[i].Caption;
    end;
  end;

  if TabCaption <> '' then begin
    if PromptAndValidateQRCodeAndTitle(TabCaption, QRCode, QRString, Title) then begin
      InsertSQL := 'INSERT INTO ' + TableName + ' (QRCode, Title) VALUES (:QRCode, :Title)';
      Query := NewQuery(S3DB);
      try
        Query.SQL.Text := InsertSQL;
        Query.Params.ParamByName('QRCode').AsString := QRString;
        Query.Params.ParamByName('Title').AsString := Title;
        Query.ExecSQL;
        S3DB.Transaction.Commit;
      finally
        EndQuery(Query);
      end;

      for i := 0 to PageControl1.PageCount - 1 do begin
        TabSheet := PageControl1.Pages[i];
        if StringReplace(TabSheet.Caption, ' ', '', [rfReplaceAll]) = ShortName then begin
          ListBox := TListBox(FindAnyComponent(TabSheet, 'lb' + ShortName + 'List'));
          if Assigned(ListBox) then begin
            LoadDataIntoListBox(ListBox, TableName);
            MatchIndex := ListBox.Items.IndexOf(QRString);
            if MatchIndex >= 0 then begin
              ListBox.ItemIndex := MatchIndex;
              ListBox.OnClick(ListBox);
            end;
          end;
        end;
      end;

      Result := True;
    end;
  end;
end;

initialization
  GlobalComponentList := TStringList.Create;

finalization
  GlobalComponentList.Free;

end.
