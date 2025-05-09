(*
@AI:unit-summary:
- This Pascal unit defines a graphical user interface for managing a build list of components, allowing users to add, edit, and delete entries associated with various hardware components.
- It interacts with a SQLite database to store and retrieve component details, including QR codes and titles, and dynamically generates UI elements based on the data structure defined in an INI file.
- The unit also handles user input validation and updates the UI accordingly based on user actions.
*)
unit frmMain;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls, StdCtrls,
  ExtCtrls, LCLType, Buttons,
  RegExpr, SQLite3Conn, SQLite3, SQLDB;

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
    procedure PopulateComponentList (ComponentName: string; TargetListBox: TListBox);

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
(*
@AI:summary: This function likely searches for a component by its name within a specified root component.
@AI:params: Root: The root component from which the search for the named component begins.
@AI:params: Name: The name of the component to be searched for within the root component.
@AI:returns: The function is expected to return the found component or nil if not found.
*)
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
(*
@AI:summary: Looks through structure.ini in the [Order] section to find if the tabs caption is something we create dynamically
@AI:params: TabCaption: The caption of the tab to be evaluated for dynamic status.
@AI:returns: Returns true if the tab is dynamic, otherwise false.
*)
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
(*
@AI:summary: Given the Sender as the root control, this function will delete all tWinControls that are built and have their ownership set to the Sender control at runtime.
@AI:params: Sender: The component whose child objects are to be deleted.
@AI:returns: No output is expected.
TODO: Rewrite this to get the whole "Exit" stuff out of this code.  Horrible code style!
*)
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
(*
@AI:summary: This badly named function is for the menu item to refresh the build list ListBox on the form UI.  This function will re-highlight the last selected build item on reload if the item still exists in the [BuildList] SQLite table
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)      var
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
(*
@AI:summary: This function prompts the user to input a QR code and a title, then validates the input.
@AI:params: TabCaption: The caption for the tab, likely used to inform the user about the context of the prompt.
@AI:params: QRTypes: Specifies the type of QR code to validate against, ensuring the correct format is used.
@AI:params: QRString: An output parameter that will hold the validated QR code string provided by the user.
@AI:params: Title: An output parameter that will hold the validated title string provided by the user.
@AI:returns: A boolean indicating whether the validation was successful or not.
*)
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
(*
@AI:summary: Validates a QR code based on its type and content.
@AI:params: QRType: Specifies the type of QR code to validate.
@AI:params: QRString: The actual string content of the QR code to be validated.
@AI:returns: Returns true if the QR code is valid, otherwise false.
*)
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
(*
TODO: Review what the status of this function is specifically.
@AI:summary: This function will call the appropriate add/edit/delete for components listed in a build.
@AI:params: Mode: Specifies the action mode for building the component.
@AI:params: ShortName: Represents the name of the component to be built.
@AI:params: OptionalDeviceID: An optional identifier for a device associated with the component, defaulting to -1 if not provided.
@AI:returns: Returns a boolean indicating the success or failure of the component build action.
*)
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
(*
@AI:summary: This function prompts the user to provide a QR code (YYMM-### format) and a general description of the PC build.
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
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
(*
@AI:summary: Sets the Build List menu items Enabled property to allow or deny if the system is capable of deleting that build item.  If no build is selected in the list, the delete button is disabled.
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
begin
  mnuDeleteBuild.Enabled := lbBuildList.ItemIndex <> -1;
end;

procedure TForm1.mnuDeleteBuildClick (Sender: TObject);
(*
@AI:summary: This function will ask the user to confirm if the build is to be deleted from the database.  This will release the associated parts back into the queue to be put into other builds.
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
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
(*
@AI:summary: Initializes the form when it is created.  Establishes the run-time dynamically created tabs.  This also handles creating menu items for each selected tab so that each tab has its own Add/Edit/Delete functionality.
@AI:params: Sender: The object that triggered the form creation event.
@AI:returns:
*)
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
(*
@AI:summary: This function handles idle events for the application, potentially performing tasks when the application is not busy.
@AI:functionality:
- Enables/Disables the Memo1 field if something is selected in the BuildList Listbox on the forms UI
- If no item is selected, and the contents of the memo is not clear, then clear the memo.
@AI:params: Sender: The object that triggered the idle event, typically the application form.
@AI:params: Done: A boolean variable that indicates whether the idle processing is complete or if further processing is needed.
@AI:returns:
*)
begin
  Memo1.Enabled := lbBuildList.ItemIndex <> -1;
  if (lbBuildList.ItemIndex = -1) and (Memo1.Text <> '') then begin
    Memo1.Text := '';
  end;
end;

procedure TForm1.FormDestroy (Sender: TObject);
(*
@AI:summary: This function likely handles cleanup tasks when the form is destroyed.
@AI:params: Sender: The object that triggered the event, typically the form itself.
@AI:returns:
*)
begin
  // TODO: Really gotta validate this cleanup process.
  // Clean up everything in the tab sheets
  while ListOfCustomObjects.Count > 0 do begin
  end;
  MenuToggleList.Free;

  DeleteChildObjects(TComponent(sbSystemBuildSpecs));
  CleanupDynamicMenus;
end;

procedure TForm1.lbBuildListClick (Sender: TObject);
(*
@AI:summary: Updates the Build sheet to indicate what components are in the selected build.
@AI:params: Sender: The object that triggered the event, typically the list box itself.
@AI:returns:
*)
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
(*
@AI:summary: If there has been any change to the Memo field for this build, update the SQLite table with the note details.
@AI:params: Sender: The object that triggered the exit event, typically the memo component itself.
@AI:returns:
*)
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
(*
@AI:summary: ##This function is currently a NO-OP function.##  Its intent will be used to reset the build so that it has no components associated to it.  Useful when migrating components from one PC case to another.
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
begin
  // This will wipe out ALL components to this build
  // Use of this will not delete components, just "unassociate" them to a build
end;

procedure TForm1.mnuAddToBuildManifestClick (Sender: TObject);
(*
@AI:summary: ##This function is currently a NO-OP function.##  This functions intent is to bring up a dialog box that will allow the user to scan several QR codes at once, and the software will then associate the QR codes to whatever build is found during all the scans.
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
begin
  // This will pop up a dialog where the user can zap all the QR codes into a box
  // On submission, each QR will be added to the build ID
  // Duplicates are ignored
end;

procedure TForm1.PageControl1Change (Sender: TObject);
(*
@AI:summary: Update the form UI for the specified tab.  Update the visibility of the menu item for the selected tab.  This is only a UI update, no data change here.
@AI:params: Sender: The object that triggered the event, typically the page control itself.
@AI:returns:
*)
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
(*
@AI:summary: In each dynamicly created tab, there's a listbox that holds an ID for components (This is where Device_Components comes in).  This function first clears, then populates the listbox with the listbox.item[x].object[y] being represented to the SQLite tables PK field
@AI:params: ListBox: The ListBox component where the data will be displayed.
@AI:params: TableName: The name of the table from which data will be retrieved.
@AI:returns:
*)
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

function SafeComponentName (Raw: string): string;
(*
@AI:summary: This function likely sanitizes or processes a raw string to ensure it is safe for use as a component name.
@AI:params: Raw: The input string that needs to be sanitized or processed.
@AI:returns: A sanitized string that is safe for use as a component name.
*)
var
  Cleaned: string;
  i: integer;
begin
  SetLength(Cleaned, Length(Raw));
  for i := 1 to Length(Raw) do begin
    if Raw[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then begin
      Cleaned[i] := Raw[i];
    end else begin
      Cleaned[i] := '_';
    end;
  end;

  Cleaned := Trim(Cleaned);
  if Cleaned = '' then begin
    Cleaned := 'X';
  end;

  if Cleaned[1] in ['0'..'9'] then begin
    Cleaned := 'C_' + Cleaned;
  end;

  Result := Cleaned;
end;

procedure AddGlobalFieldsToFrame (Frame: TFrame1; ComponentName: string);
(*
@AI:summary: This function likely adds global fields to a specified frame component.
@AI:params: Frame: The frame to which global fields will be added.
@AI:params: ComponentName: The name of the component for which global fields are being added.
@AI:returns:
*)
var
  Q: TSQLQuery;
  FieldName, FieldLabel, FieldType, ComboValues: string;
  FieldY: integer;
  LabelCtrl: TLabel;
  EditCtrl: TEdit;
  ComboCtrl: TComboBox;
const
  LineDisplacement = 2;
begin
  FieldY := LineDisplacement;
  Q := NewQuery(S3DB);
  try
    Q.SQL.Text := 'SELECT FieldName, FieldLabel, ComponentType, ComboValues FROM LayoutMap WHERE Component = ''GLOBAL'' AND Origin = ''G'' ORDER BY SortOrder';
    Q.Open;

    while not Q.EOF do begin
      FieldName := Q.FieldByName('FieldName').AsString;
      FieldLabel := Q.FieldByName('FieldLabel').AsString;
      FieldType := LowerCase(Q.FieldByName('ComponentType').AsString);
      ComboValues := Q.FieldByName('ComboValues').AsString;

      // Label
      LabelCtrl := TLabel.Create(Frame.GlobalDetails);
      LabelCtrl.Parent := Frame.GlobalDetails;
      LabelCtrl.Caption := FieldLabel;
      LabelCtrl.Left := 8;
      LabelCtrl.Top := FieldY;
      LabelCtrl.Name := SafeComponentName(ComponentName + '__' + FieldName + '__lbl');

      // Control creation based on type
      if lowercase(FieldType) = 'combo' then begin
        ComboCtrl := TComboBox.Create(Frame.GlobalDetails);
        ComboCtrl.Parent := Frame.GlobalDetails;
        ComboCtrl.Left := 250;
        ComboCtrl.Top := FieldY;
        ComboCtrl.Width := 250;
        ComboCtrl.Name := SafeComponentName(ComponentName + '__' + FieldName);
        if ComboValues <> '' then begin
          ComboCtrl.Items.Text := ComboValues;
        end;

        GlobalComponentList.AddObject(ComboCtrl.Name + '=' + ComponentName + '.' + FieldName, ComboCtrl);
        Inc(FieldY, ComboCtrl.Height + LineDisplacement);
      end else if lowercase(FieldType) = 'integer' then begin
        ComboCtrl := TComboBox.Create(Frame.GlobalDetails);
        ComboCtrl.Parent := Frame.GlobalDetails;
        ComboCtrl.Left := 250;
        ComboCtrl.Top := FieldY;
        ComboCtrl.Width := 250;
        ComboCtrl.Name := SafeComponentName(ComponentName + '__' + FieldName);

        GlobalComponentList.AddObject(ComboCtrl.Name + '=' + ComponentName + '.' + FieldName, ComboCtrl);
        Inc(FieldY, ComboCtrl.Height + LineDisplacement);
      end else // Default to TEXT
      begin
        EditCtrl := TEdit.Create(Frame.GlobalDetails);
        EditCtrl.Parent := Frame.GlobalDetails;
        EditCtrl.Left := 250;
        EditCtrl.Top := FieldY;
        EditCtrl.Width := 250;
        EditCtrl.Name := SafeComponentName(ComponentName + '__' + FieldName);

        GlobalComponentList.AddObject(EditCtrl.Name + '=' + ComponentName + '.' + FieldName, EditCtrl);
        Inc(FieldY, EditCtrl.Height + LineDisplacement);
      end;

      Q.Next;
    end;

  finally
    EndQuery(Q);
  end;
end;

procedure TForm1.CreateTab (ComponentName: string);
(*
@AI:summary: When called, this function will create the tab and sub components required to display the component list.  This does not deal with the design-time built Build List tab or menus.
@AI:params: ComponentName: This is the type of component that this tab is responsible for displaying, such as motherboards, sound cards, etc.
@AI:returns:
*)
var
  Tab: TTabSheet;
  LeftPanel: TGroupBox;
  ItemList: TListBox;
  Frame1: TFrame1;
  Frame2: TFrame2;
  Q: TSQLQuery;
  GroupName, FieldName, FieldLabelText: string;
  FieldLabel: TLabel;
  LastGroupName: string;
  FieldY: integer;
  FrameCount: integer;
  GlobalY: integer;
  GlobalLabel: TLabel;
  GlobalEdit: TEdit;
  FieldType, ComboValues: string;
  Combo: TComboBox;
  Spin: tComboBox;
  Edit: TEdit;
begin
  Tab := TTabSheet.Create(PageControl1);
  Tab.PageControl := PageControl1;
  Tab.Caption := ComponentName;

  // --- LEFT PANEL: Record list ---
  LeftPanel := TGroupBox.Create(Tab);
  LeftPanel.Parent := Tab;
  LeftPanel.Align := alLeft;
  LeftPanel.Width := 200;
  LeftPanel.Caption := 'Entries';
  LeftPanel.Name := SafeComponentName('gb__' + ComponentName + '__List');

  ItemList := TListBox.Create(LeftPanel);
  ItemList.Parent := LeftPanel;
  ItemList.Align := alClient;
  ItemList.Name := SafeComponentName('lb__' + ComponentName + '__List');
  ItemList.Sorted := True;
  ItemList.OnClick := @ListBoxClick;

  // Create Frame1 (holds Frame2s horizontally)
  Frame1 := TFrame1.Create(Tab);
  Frame1.Name := SafeComponentName('frm_' + ComponentName);
  Frame1.Parent := Tab;
  Frame1.Align := alClient;

  // --- Populate GlobalDetails panel ---
  GlobalY := 8;

  AddGlobalFieldsToFrame(Frame1, ComponentName);

  // Reset group tracking
  LastGroupName := '';
  Frame2 := nil;
  FrameCount := 0;

  Q := NewQuery(S3DB);
  try
    Q.SQL.Text := 'SELECT FieldName, FieldLabel, GroupName, ComponentType, ComboValues FROM LayoutMap WHERE Component = :c ORDER BY trim(GroupName) <> '''', upper(GroupName), SortOrder';
    Q.ParamByName('c').AsString := ComponentName;
    Q.Open;

    LastGroupName := '';
    Frame2 := nil;

    while not Q.EOF do begin
      GroupName := Q.FieldByName('GroupName').AsString;
      if GroupName = '' then begin
        GroupName := 'Generic';
      end;
      FieldName := Q.FieldByName('FieldName').AsString;

      // Start a new Frame2 when group changes
      if GroupName <> LastGroupName then begin
        Frame2 := TFrame2.Create(Frame1.sbGroupScroll);
        Frame2.Name := StringReplace(ComponentName + '_' + GroupName, ' ', '', [rfReplaceAll]);
        Frame2.Parent := Frame1.sbGroupScroll;
        Frame2.Align := alLeft;
        Frame2.Width := 250;
        Frame2.Left := Frame2.Width * FrameCount;
        Frame2.CompGroupTitle.Caption := GroupName;
        Inc(FrameCount);
        Frame2.Tag := FrameCount;

        LastGroupName := GroupName;
        FieldY := 8;
      end;

      // Add Label
      FieldLabel := TLabel.Create(Frame2);
      FieldLabel.Name := StringReplace('label_' + ComponentName + '_' + GroupName + '_' + FieldName, ' ', '', [rfReplaceAll]);
      FieldLabel.Parent := Frame2.CompDetails;
      FieldLabel.Caption := FieldName;
      FieldLabel.Left := 8;
      FieldLabel.Top := FieldY;

      FieldName := Q.FieldByName('FieldName').AsString;
      FieldLabelText := Q.FieldByName('FieldLabel').AsString;
      GroupName := Q.FieldByName('GroupName').AsString;
      FieldType := Q.FieldByName('ComponentType').AsString;
      ComboValues := Q.FieldByName('ComboValues').AsString;

      // Component creation
      if FieldType = 'Combo' then begin
        Combo := TComboBox.Create(Frame2.CompDetails);
        Combo.Parent := Frame2.CompDetails;
        Combo.Left := 8;
        Combo.Top := FieldY + FieldLabel.Height + 4;
        Combo.Width := 200;
        Combo.Name := SafeComponentName(ComponentName + '__' + FieldName);

        // Add static combo values from LayoutMap
        if ComboValues <> '' then begin
          Combo.Items.Text := ComboValues;
        end;
        Inc(FieldY, FieldLabel.Height + Combo.Height + 12);

        // Add to registry
        GlobalComponentList.AddObject(Combo.Name + '=' + ComponentName + '.' + FieldName, Combo);
      end else if FieldType = 'Integer' then begin
        Spin := TComboBox.Create(Frame2.CompDetails);
        Spin.Parent := Frame2.CompDetails;
        Spin.Left := 8;
        Spin.Top := FieldY + FieldLabel.Height + 4;
        Spin.Width := 200;
        Spin.Name := SafeComponentName(ComponentName + '__' + FieldName);
        Inc(FieldY, FieldLabel.Height + Spin.Height + 12);

        GlobalComponentList.AddObject(Spin.Name + '=' + ComponentName + '.' + FieldName, Spin);
      end else begin
        // Fallback to plain edit
        Edit := TEdit.Create(Frame2.CompDetails);
        Edit.Parent := Frame2.CompDetails;
        Edit.Left := 8;
        Edit.Top := FieldY + FieldLabel.Height + 4;
        Edit.Width := 200;
        Edit.Name := SafeComponentName(ComponentName + '__' + FieldName);
        Inc(FieldY, FieldLabel.Height + Edit.Height + 12);

        GlobalComponentList.AddObject(Edit.Name + '=' + ComponentName + '.' + FieldName, Edit);
      end;

      Q.Next;
    end;

  finally
    EndQuery(Q);
  end;
end;

procedure TForm1.ListBoxClick (Sender: TObject);
(*
@AI:summary: This is a linked function to all the dynamically created listboxes for each of the dynamically created tabs.  When an item is clicked, the PopulateSpecsPane function will populate the dynamically created fields (tEdit/tCombo) with the data read from the SQLite table.
@AI:params: Sender: The object that triggered the click event, typically the ListBox itself.
@AI:returns:
*)
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
(*
@AI:summary: This is an OVERLOADED function.  Based on the tab name (Spaces removed) populate the tEdit/tCombo fields placed on the form on this tab.
@AI:params: DeviceID: The unique identifier for the device whose specifications are to be populated.
@AI:params: TabShortName: The short name of the tab where the specifications will be displayed.
@AI:returns:
TODO: Get rid of the Exit/Continue garbage
TODO: This will break due to the change from tEdits only over to tEdits and tCombos.  We'll need to work intelligence into this function.
*)
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

procedure TForm1.PopulateSpecsPane (DeviceID: integer);
(*
@AI:summary: Each dynamic tab gets a whole list of tEdits and tCombos to allow for user data updates.  This function goes through and creates the tEdits (Only, currently) and places them on the scroll with a specific name.  This I beleive is being retired as tFrame1 and tFrame2 is handling that functionality.  Will have to trace through code.
@AI:returns:
TODO: Remove the Exit/Continue garbage.  This function is likely to be rewritten anyways with the introduction of tCombos and not just tEdits littering the place.
*)
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

procedure TForm1.PopulateComponentList (ComponentName: string; TargetListBox: TListBox);
(*
@AI:summary: In each dynamic tab, this function is supposed to populate the ListBox that shows just the QRCode and name of the item.  Problem is that a proper ID is not stored with the component.
@AI:params: ComponentName: The name of the component to filter and display in the list box.
@AI:params: TargetListBox: The list box where the components will be populated.
@AI:returns:
TODO: This function is incomplete as it doesn't have a pointer back to a PK for the table.
*)
var
  qr: TSQLQuery;
  SQL: string;
begin
  TargetListBox.Clear;

  SQL := 'SELECT QRCode, Name FROM ' + ComponentName + ' ORDER BY Name ASC';

  qr := NewQuery(S3DB);
  try
    qr.SQL.Text := SQL;
    qr.Open;

    while not qr.EOF do begin
      TargetListBox.Items.Add(qr.FieldByName('QRCode').AsString + ' - ' + qr.FieldByName('Name').AsString);
      qr.Next;
    end;
  finally
    EndQuery(qr);
  end;
end;

procedure TForm1.RefreshBuildList;
(*
@AI:summary: Refreshes the list of builds displayed in the form.
@AI:params:
@AI:returns:
*)
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
(*
@AI:summary: Renders groups of components within a form.
@AI:params: None.
@AI:returns: None.
TODO: I think this has been refactored out of the tool since it's dealing with group boxes not frames like we're shifting to. Need to trace this code.
*)
var
  x: integer;
  pnl: tGroupBox;
  mi: TMenuItem;// mi = MenuItem
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
(*
@AI:summary: This function removes all bad lettering from a functions name to conform to Pascal naming standards.
@AI:params: S: The original component name that needs to be sanitized.
@AI:returns: A sanitized version of the component name as a string.
*)
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
(*
@AI:summary: This function adds a submenu item to a specified parent menu.
@AI:params: ParentMenu: The menu item to which the submenu will be added.
@AI:params: SubCaption: The text label for the submenu item.
@AI:params: TagValue: An integer value that may be used to identify or categorize the submenu item.
@AI:returns: No output is expected as this is a procedure.
*)
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
(*
@AI:summary: For the dyanmically created menus (Based on the tabs created at run time) the sub-menus created for add/edit/delete are actioned in this function.
@AI:params: Sender: The object that triggered the menu item click event, typically used to identify the source of the action.
@AI:returns: No output is expected as this is a procedure.
*)
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
(*
@AI:summary: This function goes through structure.ini in the Order section and creates the menus to represent actions for each tab, then creates the required Add/Edit/Delete sub menus.
@AI:params: None.
@AI:returns: None.
*)
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
(*
@AI:summary: This function likely handles click events for a parent menu item in a form.
@AI:params: Sender: The object that triggered the click event, typically the menu item itself.
@AI:returns:
*)
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
(*
@AI:summary: Just as there's a function to create the dynamic menus, this function destroys those created menus at application shutdown.
@AI:params:
@AI:returns:
*)
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
(*
@AI:summary: This function currently only loads notes from the database when a new Build row is selected in the Build tab.
@AI:params: None
@AI:returns: None
*)
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

procedure TForm1.AddMenuClick (Sender: TObject);
(*
@AI:summary: When a dynamic tab is selected, the "Add Component" sub menu is triggered here.  This function will effectively add a new row to the relevant table, then add a reference to that row into the Listbox.
@AI:params: Sender: Represents the object that triggered the event, typically the menu item itself.
@AI:returns:
*)
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
(*
@AI:summary: With users permission on a selected component in the currently selected tab, remove the item from the appropriate table in the SQLite3 table.
@AI:params: ShortName: The identifier for the build component to be deleted.
@AI:returns: A boolean indicating whether the deletion was successful or not.
*)
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
(*
@AI:summary: This function will add a new row to the appropriate Device_ShortName table in SQLite, defaulting to a QRCode and Title.
@AI:params: ShortName: The identifier for the build component to be added.
@AI:returns: A boolean indicating whether the addition of the build component was successful.
*)
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
(*
@AI:initialization-summary: Initializes a global component list.
@AI:initialization-actions:
- Creates a new TStringList instance and assigns it to GlobalComponentList.
@AI:GlobalVars:GlobalComponentList:This variable is the global list of all dynamically created tEdit/tCombo components.  It contains the name of the component, plus an object pointer to the component itself.
*)
  GlobalComponentList := TStringList.Create;

finalization
  GlobalComponentList.Free;

end.
