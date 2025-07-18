(*
@AI:unit-summary:
- This Pascal unit defines a graphical user interface for managing a build list of components, allowing users to add, edit, and delete entries associated with various hardware components.
- It interacts with a SQLite database to store and retrieve component details, including QR codes and titles, and dynamically generates UI elements based on the data structure defined in an INI file.
- The unit also handles user input validation and updates the UI accordingly based on user actions.
*)

// TODO: Look at the age of structure.ini and write it to the database.  If the timestamps don't change, we don't need to do database validation and we can assume it "just works".  If date doesn't exist in the DB, do the validation.
unit frmMain;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls, StdCtrls,
  ExtCtrls, LCLType, Buttons, ExtDlgs, RTTICtrls, SynEdit,
  RegExpr, SQLite3Conn, SQLite3, SQLDB, TabGrouping, ActnList, MiscFunctions;

type
  { TForm1 }

  TForm1 = class(TForm)
    ApplicationProperties1: TApplicationProperties;
    gbCompList1: TGroupBox;
    gbCompStats1: TGroupBox;
    lbBuildList: TListBox;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    mnuPasteImage: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem19: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem22: TMenuItem;
    MenuItem23: TMenuItem;
    MenuItem24: TMenuItem;
    MenuItem25: TMenuItem;
    MenuItem26: TMenuItem;
    imagePopup: TMenuItem;
    MenuItem27: TMenuItem;
    MenuItem28: TMenuItem;
    mnuExit: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem7: TMenuItem;
    mnuResetManifest: TMenuItem;
    mnuAddToBuildManifest: TMenuItem;
    OpenPictureDialog1: TOpenPictureDialog;
    PageControl2: TPageControl;
    Panel1: TPanel;
    ImageContainer: TPanel;
    Panel3: TPanel;
    PopupMenu1: TPopupMenu;
    sbSystemBuildSpecs: TScrollBox;
    sbBuildImages: TScrollBox;
    Separator2: TMenuItem;
    MenuItem8: TMenuItem;
    mnuAddBuild: TMenuItem;
    mnuDeleteBuild: TMenuItem;
    mnuBuildList: TMenuItem;
    PageControl1: TPageControl;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    AssignButtonFlashTimer: TTimer;
    tsBuildSheet: TTabSheet;

    procedure ApplicationProperties1Idle (Sender: TObject; var Done: boolean);
    procedure AssignButtonFlashTimerTimer (Sender: TObject);
    procedure FormCreate (Sender: TObject);
    procedure FormDestroy (Sender: TObject);
    procedure imagePopupClick (Sender: TObject);
    procedure lbBuildListClick (Sender: TObject);

    procedure lbBuildListMouseDown (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
    procedure Memo1Exit (Sender: TObject);
    procedure MenuItem1Click (Sender: TObject);
    procedure MenuItem4Click (Sender: TObject);
    procedure mnuExitClick (Sender: TObject);
    procedure MenuItem2Click (Sender: TObject);
    procedure mnuLoadImageClick (Sender: TObject);
    procedure mnuPasteImageClick (Sender: TObject);
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
    procedure ComponentExit (Sender: TObject);
    procedure cboPopulateNumeric (Sender: TObject);// Get unique sorted integers from the table
    procedure cboPopulateCombo (Sender: TObject);  // Get default and unique text from the table
    procedure cboItemSelected (Sender: TObject);   // Triggered when an item is selected in the dropdown
    procedure AssignBuildButtonClick (Sender: TObject);
    procedure ThumbnailClick (Sender: TObject);
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
    function HandleBuildComponentAction (Mode, ShortName: string; OptionalDeviceID: integer = -1): boolean;
    function AddBuildComponent (ShortName: string): boolean;
    function DeleteBuildComponent (ShortName: string): boolean;
    procedure AddGlobalFieldsToFrame (Frame: TFrame1; ComponentName: string);
    procedure CreateBuildAssignmentPanel (Frame: TFrame1; TabShortName: string);
    procedure UpdateBuildAssignmentStatus (const TabShortName: string);
    procedure PrepareIdleDeletes (ParentComponent: tControl);
    procedure PerformIdleDeletes;

    // Image dealings
    procedure ImportImageForComponent (ImagePath: string; ComponentType: string; ComponentID: integer);
    procedure ReloadImagesOnScreen;
    function ConvertBMPClipboardToOptimalFormat (out FileFormat: string): TMemoryStream;
    procedure SaveStreamToDatabase (InStream: tMemoryStream; Ext: string);
    function GetImageDimensions (Stream: TMemoryStream): TPoint;
    function ConvertToSupportedImage (out Stream: tMemoryStream; out ImgFmt: string): boolean;
  public
    function GetBuildIdForComponent (ComponentID: integer; Component: string): integer;
    function GetBuildNameForID (ID: integer): string;
  end;

var
  Form1: TForm1;
  GlobalComponentList: TStringList;

implementation

uses IniFiles, SimpleSQLite3, DatabaseManager, ComponentDetails,
  Clipbrd, uStreamToDB, frmBuildSheet, DB, Math, Imaging, ImagingTypes, ImagingClasses,
  ImagingJPEG, zlib, FPImage, FPReadBMP, FPWriteJPEG, FPWritePNG;

  {$R *.lfm}

  { TForm1 }
var
  MenuToggleList: TStringList;
  IdleDeleteObjects: TList;

const
  EditHeight = 25;

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
*)
var
  i, CountBefore: integer;
  ControlList: TList;
  ControlName: string;
begin
  // Code generated in this function by AI due to author being an I-D-Ten-T.
  if (Sender is TWinControl) then begin
    CountBefore := TWinControl(Sender).ControlCount;
    if CountBefore <> 0 then begin
      ControlList := TList.Create;
      for i := 0 to CountBefore - 1 do begin
        ControlList.Add(TWinControl(Sender).Controls[i]);
      end;

      // Now delete from stored list
      for i := ControlList.Count - 1 downto 0 do begin
        if (tWinControl(ControlList[i]) is TGroupBox) then begin
          tComboBox(ControlList[i]).Free;
        end else if (tWinControl(ControlList[i]) is tPanel) then begin
          DeleteChildObjects(TWinControl(ControlList[i]));
          tPanel(ControlList[i]).Free;
        end else if (TControl(ControlList[i]) is TImage) then begin
          TImage(ControlList[i]).Picture.Clear;
          tImage(ControlList[i]).Free;
        end;
      end;
      ControlList.Free;
    end;
  end;
end;

procedure TForm1.ComponentExit (Sender: TObject);
(*
@AI:summary: Securely updates a single database field when a form control loses focus, using parameterized SQL.
@AI:params: Sender: The TEdit or TComboBox control that triggered the OnExit event.
@AI:behavior:
  - Uses GlobalComponentList to determine the table and field.
  - Retrieves the currently selected DeviceID from the associated listbox.
  - Executes a parameterized UPDATE using NewQuery/EndQuery.
@AI:requires:
  - Component must be registered in GlobalComponentList.
  - Listbox must be present and contain a selected item with I2O mapping.
*)
var
  CompName, FieldName, FullKey, Value: string;
  DotPos: integer;
  ShortName, ListBoxName: string;
  ListBox: TListBox;
  DeviceID, Index: integer;
  Q: TSQLQuery;
  SQL: string;
begin
  if (Sender is TEdit) or (Sender is TComboBox) then begin
    CompName := TWinControl(Sender).Name;
    FullKey := GlobalComponentList.Values[CompName];

    DotPos := Pos('.', FullKey);
    if DotPos > 0 then begin
      FieldName := Copy(FullKey, DotPos + 1, Length(FullKey));

      if Sender is TEdit then begin
        Value := TEdit(Sender).Text;
      end else begin
        Value := TComboBox(Sender).Text;
      end;

      ShortName := Copy(CompName, 1, Pos('__', CompName) - 1);
      ListBoxName := 'lb__' + ShortName + '__List';

      ListBox := TListBox(FindAnyComponent(Form1, ListBoxName));
      if Assigned(ListBox) then begin
        Index := ListBox.ItemIndex;
        if Index <> -1 then begin
          DeviceID := O2I(ListBox.Items.Objects[Index]);

          Q := NewQuery(S3DB);
          try
            SQL := 'UPDATE Device_' + ShortName + ' SET ' + FieldName + ' = :val WHERE DeviceID = :id';
            Q.SQL.Text := SQL;
            Q.ParamByName('val').AsString := Value;
            Q.ParamByName('id').AsInteger := DeviceID;
            Q.ExecSQL;
          finally
            EndQuery(Q);
          end;
        end;
      end;
    end;
  end;
end;

(*
@AI:summary: This function will populate the combobox dropdown when selected.  It reads the database for all distinct, numeric values that have been entered for the specific field, sorts by integer.
@AI:params: Sender: The object that triggered the event, typically the object item itself.
@AI:returns:
@AI:notes: This function is called by the "OnDropDown" event and is assigned within the CreateTab function.
*)
procedure TForm1.cboPopulateNumeric (Sender: TObject);
var
  q: TSQLQuery;
  cbo: TComboBox;
  CompName: string;
  FieldName: string;
  lb: TListBox;
  TabShortName: string;
  sql: string;
  v: string;
begin
  CompName := PageControl1.ActivePage.Caption;
  TabShortName := StringReplace(CompName, ' ', '', [rfReplaceAll]);
  // Determine if there is an item selected in the current tabs item listbox
  lb := nil;
  lb := TListBox(FindAnyComponent(form1, 'lb__' + TabShortName + '__List'));
  if Assigned(lb) and (lb.ItemIndex <> -1) then begin
    // Now retrieve all the unique values for all entries, sorted by integer based values.
    cbo := TComboBox(Sender);
    cbo.Items.Clear;
    FieldName := copy(cbo.Name, Pos('__', cbo.Name) + 2, length(cbo.Name));
    sql := 'select distinct ' + FieldName + ' from Device_' + TabShortName + ' order by cast(' + FieldName + ' as integer)';
    q := NewQuery(s3db);
    q.SQL.Text := sql;
    q.Open;
    while not q.EOF do begin
      v := trim(q.FieldByName(FieldName).AsString);
      if length(v) > 0 then begin
        cbo.Items.Add(q.FieldByName(FieldName).AsString);
      end;
      q.Next;
    end;
    EndQuery(q);

  end;
end;

(*
@AI:summary: This function will populate the combobox dropdown when selected.  It first reads what specific values are needed for this dropdown, then selects the other definitions found in the database for this field.  Sorted based on what the fields are specifically defined as in structure.ini.
@AI:params: Sender: The object that triggered the event, typically the object item itself.
@AI:returns:
@AI:notes: This function is called by the "OnDropDown" event and is assigned within the CreateTab function.
*)
procedure TForm1.cboPopulateCombo (Sender: TObject);
var
  q: TSQLQuery;
  cbo: TComboBox;
  sl: TStringList;
  CompName: string;
  FieldName: string;
  DbField: string;
  lb: TListBox;
  TabShortName: string;
begin
  CompName := PageControl1.ActivePage.Caption;
  TabShortName := StringReplace(CompName, ' ', '', [rfReplaceAll]);
  // Determine if there is an item selected in the current tabs item listbox
  lb := TListBox(FindAnyComponent(form1, 'lb__' + TabShortName + '__List'));
  if Assigned(lb) and (lb.ItemIndex <> -1) then begin
    cbo := TComboBox(Sender);
    cbo.Items.Clear;
    FieldName := copy(cbo.Name, Pos('__', cbo.Name) + 2, maxlongint);
    // Pick off the existing defined values
    q := NewQuery(S3DB);
    q.SQL.Text := 'select ComboValues from LayoutMap where (Component=''GLOBAL'' or Component=:c) and FieldName=:f and ComponentType=''Combo'' order by Component<>''GLOBAL'' limit 1';
    q.ParamByName('c').Text := CompName;
    q.ParamByName('f').Text := FieldName;
    q.Open;
    if not q.EOF then begin
      cbo.Items.Text := q.FieldByName('ComboValues').AsString;
    end;
    EndQuery(q);

    // Now locate anything set that isn't part of the defaults
    q := NewQuery(s3db);
    q.sql.Text := 'select distinct ' + FieldName + ' from Device_' + TabShortName + ' order by lower(' + FieldName + ')';
    q.Open;
    sl := TStringList.Create;
    while not q.EOF do begin
      // Get the current contents of whats in the dropdown
      sl.Text := cbo.Items.Text;
      sl.Text := trim(LowerCase(sl.Text));

      // See if there's an item found
      if (trim(q.FieldByName(FieldName).AsString) <> '') and (sl.IndexOf(q.FieldByName(FieldName).AsString.ToLower) = -1) then begin
        cbo.Items.Add(q.FieldByName(FieldName).AsString);
      end;

      q.Next;
    end;
    sl.Free;
    EndQuery(q);
  end;
end;

procedure TForm1.cboItemSelected (Sender: TObject);
(*
@AI:summary: This function will trigger when any dynamically created combo box has an item selected from its own dropdown box.  This immediately updates the database table.
@AI:params: Sender: The object that triggered the event, typically the object item itself.
@AI:returns:
*)
var
  cbo: TComboBox;
  sl: TStringList;
  CompName: string;
  FieldName: string;
  DbField: string;
  CompID: integer;
  Q: TSQLQuery;
  lb: TListBox;
  TabShortName: string;
  sql: string;
begin
  CompName := PageControl1.ActivePage.Caption;
  TabShortName := StringReplace(CompName, ' ', '', [rfReplaceAll]);
  // Determine if there is an item selected in the current tabs item listbox
  lb := TListBox(FindAnyComponent(form1, 'lb__' + TabShortName + '__List'));
  if Assigned(lb) and (lb.ItemIndex <> -1) then begin
    // Get the text, toss it to the DB
    cbo := TComboBox(Sender);
    q := NewQuery(S3DB);
    CompID := o2i(lb.Items.Objects[lb.ItemIndex]);
    DbField := tCombobox(Sender).Name;
    DBField := copy(dbField, pos('__', DBField) + 2, length(dbfield));
    sql := 'update Device_' + TabShortName + ' set ' + DBField + '=:v where DeviceID=:d';
    q.SQL.Text := sql;
    q.ParamByName('v').AsString := cbo.Items[cbo.ItemIndex];
    q.ParamByName('d').AsInteger := CompID;
    q.ExecSQL;
    EndQuery(q);
  end;
end;

procedure TForm1.MenuItem8Click (Sender: TObject);
(*
@AI:summary: This badly named function is for the menu item to refresh the build list ListBox on the form UI.  This function will re-highlight the last selected build item on reload if the item still exists in the [BuildList] SQLite table
@AI:params: Sender: The object that triggered the event, typically the menu item itself.
@AI:returns:
*)
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
  //  ListOfCustomObjects := TStringList.Create;

  DeleteChildObjects(sbSystemBuildSpecs);
  RefreshBuildList;
  IdleDeleteObjects := TList.Create;

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
var
  lb: TListBox;
  IsBuildSheet: boolean;
  HasImage: boolean;
  HasSelection: boolean;
begin
  Memo1.Enabled := lbBuildList.ItemIndex <> -1;
  if (lbBuildList.ItemIndex = -1) and (Memo1.Text <> '') then begin
    Memo1.Text := '';
  end;

  lb := TListBox(FindAnyComponent(PageControl1.ActivePage, 'lb__' + SafeComponentName(PageControl1.ActivePage.Caption) + '__list'));
  IsBuildSheet := PageControl1.ActivePage = tsBuildSheet;
  HasImage := Clipboard.HasFormat(CF_BITMAP);

  if IsBuildSheet then begin
    HasSelection := lbBuildList.ItemIndex <> -1;
  end else begin
    HasSelection := Assigned(lb) and (lb.ItemIndex <> -1);
  end;


  mnuPasteImage.Enabled := HasImage and HasSelection;

  if IdleDeleteObjects.Count > 0 then begin
    PerformIdleDeletes;
  end;
end;

var
  FlashGreenDirection: integer = 10;

procedure TForm1.AssignButtonFlashTimerTimer (Sender: TObject);
var
  ButtonAction: TPanel;
  CurCol: TColor;
  Prefix: string;
  TabShortName: string;
  CurrentGreen: integer;
begin
  TabShortName := SafeComponentName(PageControl1.ActivePage.Caption);
  Prefix := TabShortName + '__BuildAssign__';
  ButtonAction := TPanel(FindAnyComponent(PageControl1.ActivePage, SafeComponentName(Prefix + 'Panel')));
  if PageControl1.ActivePage <> tsBuildSheet then begin
    if assigned(ButtonAction) then begin
      CurCol := ButtonAction.Color;
      if CurCol = clDefault then begin
        CurCol := RGBToColor(255, 10, 0);
        FlashGreenDirection := 10;
      end;
      CurrentGreen := curcol and $00ff00 shr 8;
      if (CurrentGreen >= 240) or (CurrentGreen = 0) then begin
        FlashGreenDirection := -FlashGreenDirection;
      end;
      CurrentGreen := CurrentGreen + FlashGreenDirection;
      CurCol := RGBToColor(255, CurrentGreen, 0);
      ButtonAction.Color := CurCol;
    end;
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

  MenuToggleList.Free;

  DeleteChildObjects(TComponent(sbSystemBuildSpecs));
  CleanupDynamicMenus;
  IdleDeleteObjects.Free;
end;

procedure TForm1.imagePopupClick (Sender: TObject);
var
  ImageID: integer;
  q: TSQLQuery;
begin
  if Application.MessageBox('Are you sure you wish to delete this image?', 'Delete Image', MB_YESNO + MB_ICONQUESTION) = ID_YES then begin
    ImageID := TImage(PopupMenu1.PopupComponent).Tag;
    q := NewQuery(s3db);
    q.SQL.Text := 'delete from ComponentImages where ImageID=:ImageID';
    q.ParamByName('ImageID').AsInteger := ImageID;
    q.ExecSQL;
    EndQuery(q);
    ReloadImagesOnScreen;
  end;

end;



procedure TForm1.lbBuildListClick (Sender: TObject);
(*
@AI:summary: Updates the Build sheet to indicate what components are in the selected build.
@AI:params: Sender: The object that triggered the event, typically the list box itself.
@AI:returns:
*)
begin
  sbSystemBuildSpecs.BeginUpdateBounds;
  DeleteChildObjects(TComponent(sbSystemBuildSpecs));
  RenderComponentGroups;
  sbSystemBuildSpecs.EndUpdateBounds;
  LoadBuildDetails;
  ReloadImagesOnScreen;
end;

procedure TForm1.lbBuildListMouseDown (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  lbBuildList.ItemIndex := lbBuildList.GetIndexAtY(y);
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

procedure TForm1.MenuItem1Click (Sender: TObject);
begin
  BuildSheet.btnClearSheet.Click;
  if BuildSheet.ShowModal = mrOk then begin
    PageControl1.PageIndex:=0;
    MenuItem8Click(nil);
  end;
end;

procedure TForm1.MenuItem4Click (Sender: TObject);
begin

end;

procedure TForm1.mnuExitClick (Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.MenuItem2Click (Sender: TObject);
begin
  // Keeping this in for now, but chucking this into Git for now so I can return to this later.
  //CameraForm.ShowModal;
end;


procedure TForm1.ImportImageForComponent (ImagePath: string; ComponentType: string; ComponentID: integer);
var
  Img: TImageData;
  OutStream: TMemoryStream;
  //  CompStream: TMemoryStream;
  //  CRC32: string;
  SQL: string;
  Q: TSQLQuery;
  ImageID: integer;
  FileName: string;
  lWidth, lHeight: integer;
  WhatIKnow: tWhatINeedToKnow;
begin
  // Load image from disk
  if not LoadImageFromFile(ImagePath, Img) then begin
    raise Exception.Create('Failed to load image: ' + ImagePath);
  end;

  // Resize the image to maintain aspect ratio
  ResizeImageMax(Img, 1024, 1024);
  lWidth := Img.Width;
  lHeight := Img.Height;

  // Convert to JPEG
  OutStream := TMemoryStream.Create;
  try
    SaveImageToStream('jpg', OutStream, Img);
    OutStream.Position := 0;

    // Insert placeholder to get ImageID
    SQL := 'INSERT or replace INTO ComponentImages (ComponentType, ComponentID, FileName, Format, Width, Height, OriginalFileName) VALUES (:ctype, :cid, :fname, :fmt, :w, :h, :oname);';
    Q := NewQuery(S3DB);
    Q.SQL.Text := SQL;
    Q.ParamByName('ctype').AsString := ComponentType;
    Q.ParamByName('cid').AsInteger := ComponentID;
    Q.ParamByName('fname').AsString := ''; // will update after we get ID
    Q.ParamByName('fmt').AsString := 'JPEG';
    Q.ParamByName('w').AsInteger := lWidth;
    Q.ParamByName('h').AsInteger := lHeight;
    Q.ParamByName('oname').AsString := ExtractFileName(ImagePath);
    //Q.ParamByName('rd').LoadFromStream(CompStream, ftBlob);
    Q.ExecSQL;

    // Get ImageID
    Q.SQL.Text := 'SELECT last_insert_rowid() AS ImageID;';
    Q.Open;
    ImageID := Q.FieldByName('ImageID').AsInteger;
    EndQuery(Q);

    WhatIKnow := tWhatINeedToKnow.Create;
    with WhatIKnow do begin
      Database := S3DB;
      FieldForBlob := 'RawData';
      FieldForID := 'ImageID';
      TableToWorkWith := 'ComponentImages';
      RecordID := ImageID;
      CompressedContent := True;
      StreamToDB(WhatIKnow, OutStream);
    end;
    WhatIKnow.Free;

    // Build final name
    FileName := Format('%s_%d_%d.jpg', [ComponentType, ComponentID, ImageID]);

    // Update FileName in DB
    SQL := 'UPDATE ComponentImages SET FileName = :fname WHERE ImageID = :id;';
    Q := NewQuery(S3DB);
    Q.SQL.Text := SQL;
    Q.ParamByName('fname').AsString := FileName;
    Q.ParamByName('id').AsInteger := ImageID;
    Q.ExecSQL;
    EndQuery(Q);

  finally
    OutStream.Free;
  end;

  (* DEBUGGING - Validate that what goes in, can come out )
  CompStream := TMemoryStream.Create;
  OutStream := TMemoryStream.Create;
  sql := 'select Filename, UncompressedSize, RawData from ComponentImages where ImageID=:id';
  q := NewQuery(s3db);
  q.SQL.Text := sql;
  q.ParamByName('id').AsInteger := ImageID;
  q.Open;
  ImagePath := '';
  if not q.EOF then begin
    TBlobField(q.FieldByName('RawData')).SaveToStream(CompStream);
    CompStream.Position := 0;
    lWidth := Q.FieldByName('UncompressedSize').AsInteger;
    // I have a RAM DRIVE, so, change this to whatever path you need
    ImagePath := 'r:\' + Q.FieldByName('Filename').AsString;
    q.Next;
  end;
  EndQuery(q);
  if ImagePath <> '' then begin
    OutStream := DecompressZlib(CompStream, lWidth);
    OutStream.SaveToFile(ImagePath);
  end;
  OutStream.Free;
  CompStream.Free;
  //*)
end;

procedure AssignImageDataToBitmap (const Img: TImageData; Target: TBitmap);
var
  Row: integer;
  Src: pbyte;
  Dest: pbyte;
begin
  Target.SetSize(Img.Width, Img.Height);
  Target.PixelFormat := pf32bit;

  for Row := 0 to Img.Height - 1 do begin
    Src := pbyte(Img.Bits) + (Row * Img.Width * 4);      // assuming ifA8R8G8B8
    Dest := Target.ScanLine[Row];
    Move(Src^, Dest^, Img.Width * 4);
  end;
end;

procedure LoadImageToControl (var Img: TImageData; Target: TImage);
var
  Converted: TImageData;
  Row: integer;
  Src, Dest: pbyte;
  Bmp: TBitmap;
begin
  Converted := Img;

  // If converted, remember to free later
  if Img.Format <> ifA8R8G8B8 then begin
    ConvertImage(Converted, ifA8R8G8B8);
  end;

  Bmp := TBitmap.Create;
  try
    Bmp.PixelFormat := pf32bit;
    Bmp.SetSize(Converted.Width, Converted.Height);

    for Row := 0 to Converted.Height - 1 do begin
      Src := pbyte(Converted.Bits) + (Row * Converted.Width * 4);
      Dest := Bmp.ScanLine[Row];
      Move(Src^, Dest^, Converted.Width * 4);
    end;

    Target.Picture.Assign(Bmp);
  finally
    Bmp.Free;
    if @Converted <> @Img then begin
      FreeImage(Converted);
    end;  // Only free if ConvertImage changed the buffer
  end;
end;

procedure ResetImage (var Img: TImageData);
begin
  if Img.Bits <> nil then begin
    FreeImage(Img);
  end;
  FillChar(Img, SizeOf(Img), 0); // Always reset afterward
end;

procedure CenterImageInPanel (Image: TImage; Ratio: float = 0.9);
var
  Panel: TPanel;
  ImgRatio, PanelRatio: double;
  NewWidth, NewHeight: integer;
begin
  if not Assigned(Image) or not Assigned(Image.Picture) or
    (Image.Picture.Width = 0) or (Image.Picture.Height = 0) then begin
    Exit;
  end;

  if not (Image.Parent is TPanel) then begin
    Exit;
  end;

  Panel := TPanel(Image.Parent);

  // Calculate aspect ratios
  ImgRatio := Image.Picture.Width / Image.Picture.Height;
  PanelRatio := Panel.ClientWidth / Panel.ClientHeight;

  // Scale image dimensions while preserving aspect ratio
  if ImgRatio > PanelRatio then begin
    // Fit by width
    NewWidth := Panel.ClientWidth;
    NewHeight := Round(NewWidth / ImgRatio);
  end else begin
    // Fit by height
    NewHeight := Panel.ClientHeight;
    NewWidth := Round(NewHeight * ImgRatio);
  end;

  NewHeight := trunc(NewHeight * Ratio);
  NewWidth := trunc(NewWidth * Ratio);

  // Apply size
  Image.SetBounds(
    (Panel.ClientWidth - NewWidth) div 2,
    (Panel.ClientHeight - NewHeight) div 2,
    NewWidth,
    NewHeight
    );
end;

procedure LoadImageBlobIntoControl (var q: TSQLQuery; var ImageControl: TImage);
var
  CompressedStream, TrimmedStream, DecompressedStream: TMemoryStream;
  Img: TImageData;
  OriginalSize: QWord;
begin
  CompressedStream := TMemoryStream.Create;
  TrimmedStream := nil;
  DecompressedStream := nil;

  try
    TBlobField(q.FieldByName('RawData')).SaveToStream(CompressedStream);
    CompressedStream.Position := 0;
    CompressedStream.SaveToFile('r:\Compressed' + q.FieldByName('ImageID').AsString + '.dat');

    if CompressedStream.Size > SizeOf(QWord) then begin
      // Read footer
      CompressedStream.Position := CompressedStream.Size - SizeOf(QWord);
      OriginalSize := CompressedStream.ReadQWord;

      // Extract compressed body
      TrimmedStream := TMemoryStream.Create;
      CompressedStream.Position := 0;
      TrimmedStream.LoadFromStream(CompressedStream);
      //      TrimmedStream.CopyFrom(CompressedStream, CompressedStream.Size - SizeOf(QWord));
      TrimmedStream.Position := 0;

      // Decompress
      DecompressedStream := DecompressZlib(TrimmedStream, OriginalSize);
      DecompressedStream.SaveToFile('R:\Test' + IntToStr(q.FieldByName('ImageID').AsInteger) + '.jpg');
    end else begin
      DecompressedStream := TMemoryStream.Create;
    end; // Empty fallback

    // Validate output
    if DecompressedStream.Size > 0 then begin
      DecompressedStream.Position := 0;
      LoadImageFromStream(DecompressedStream, Img);
      DecompressedStream.Position := 0;
      LoadImageToControl(Img, ImageControl);
      CenterImageInPanel(ImageControl);
    end;

  finally
    CompressedStream.Free;
    TrimmedStream.Free;
    DecompressedStream.Free;
  end;
end;


procedure TForm1.ReloadImagesOnScreen;
const
  BuildImageQuery = 'SELECT * FROM ComponentImages WHERE (ComponentType = ''Build List'' AND ComponentID = :BuildID) OR EXISTS ( SELECT 1 FROM BuildComponents WHERE BuildID = :BuildID AND ' +
    'BuildComponents.Component = ComponentImages.ComponentType AND BuildComponents.ComponentID = ComponentImages.ComponentID ) ORDER BY ComponentType <> ''Build List'', LOWER(ComponentType), ImageID;';
  ComponentImageQuery = 'select * from ComponentImages where ComponentType=:ComponentType and ComponentID=:ComponentID';
var
  BuildID: integer;
  ComponentType: string;
  ComponentID: integer;
  CompsInBld: TSQLQuery;
  sql: string;
  Panel: TPanel;
  Image: TImage;
  Img: TImageData;
  CompressedStream, DecompressedStream: TMemoryStream;
  ImageStream: TMemoryStream;
  PropX, PropY: integer;
  ActiveLB: TListBox;
begin
  //DeleteChildObjects(sbBuildImages);
  PrepareIdleDeletes(sbBuildImages);
  if PageControl1.ActivePage = tsBuildSheet then begin
    ActiveLB := lbBuildList;
    sql := BuildImageQuery;
  end else begin
    ActiveLB := tListbox(FindAnyComponent(PageControl1.ActivePage, 'lb__' + SafeComponentName(PageControl1.ActivePage.Caption) + '__List'));
    sql := ComponentImageQuery;
  end;
  if ActiveLB.ItemIndex > -1 then begin
    BuildID := O2I(ActiveLB.Items.Objects[ActiveLB.ItemIndex]);
    CompsInBld := NewQuery(S3DB);
    CompsInBld.SQL.Text := sql;
    if ActiveLB = lbBuildList then begin
      CompsInBld.ParamByName('BuildID').AsInteger := BuildID;
    end else begin
      CompsInBld.ParamByName('ComponentType').AsString := SafeComponentName(PageControl1.ActivePage.Caption);
      CompsInBld.ParamByName('ComponentID').AsInteger := BuildID; // Recycling -- This is to be thought of as the "ComponentID" as in the database table.
    end;
    CompsInBld.Open;
    while not CompsInBld.EOF do begin
      Panel := TPanel.Create(sbBuildImages);
      Panel.Caption := ' ';
      Panel.Name := SafeComponentName(CompsInBld.FieldByName('FileName').AsString);
      Panel.Parent := sbBuildImages;
      Panel.Align := alLeft;
      Panel.Left := MaxSmallint - 1;
      Panel.Width := Panel.Height;
      //Panel.Repaint;

      Image := TImage.Create(Panel);
      Image.Parent := Panel;
      Image.Stretch := True;
      Image.Name := 'img' + SafeComponentName(Panel.Name);
      Image.OnDblClick := @ThumbnailClick;
      Image.Tag := CompsInBld.FieldByName('ImageID').AsInteger;
      Image.PopupMenu := PopupMenu1;

      LoadImageBlobIntoControl(CompsInBld, Image);

      CompsInBld.Next;
    end;
    EndQuery(CompsInBld);

  end;
  Application.ProcessMessages;
  for PropX := 0 to sbBuildImages.ComponentCount - 1 do begin
    if sbBuildImages.Components[PropX] is TPanel then begin
      Panel := tPanel(sbBuildImages.Components[PropX]);
      if Panel.Height <> sbBuildImages.ClientHeight then begin
        Panel.SetBounds(Panel.Left, panel.Top, sbBuildImages.ClientHeight, sbBuildImages.ClientHeight);
      end;
    end;
  end;
end;

procedure TForm1.mnuLoadImageClick (Sender: TObject);
var
  i: integer;
  ComponentType: string;
  ComponentID: integer;
  ListBox: TListBox;
  CurrentTab: TTabSheet;
begin
  OpenPictureDialog1.Options := [ofAllowMultiSelect];
  OpenPictureDialog1.Filter := 'Common Image Files (*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.tif;*.tiff)|*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.tif;*.tiff|All Files (*.*)|*.*';
  if OpenPictureDialog1.Execute then begin
    CurrentTab := PageControl1.ActivePage;
    ComponentType := CurrentTab.Caption;
    if PageControl1.ActivePage = tsBuildSheet then begin
      ListBox := lbBuildList;
    end else begin
      Listbox := tListbox(FindAnyComponent(Form1, 'lb__' + SafeComponentName(ComponentType) + '__List'));
    end;
    if assigned(Listbox) then begin
      ComponentID := o2i(ListBox.Items.Objects[ListBox.ItemIndex]);
      if ComponentID >= 0 then begin
        for i := 0 to OpenPictureDialog1.Files.Count - 1 do begin
          if PageControl1.ActivePage = tsBuildSheet then begin
            ImportImageForComponent(OpenPictureDialog1.Files[i], 'Build List', ComponentID);
          end else begin
            ImportImageForComponent(OpenPictureDialog1.Files[i], SafeComponentName(ComponentType), ComponentID);
          end;
        end;
      end;
    end;
    ReloadImagesOnScreen;
  end;
end;

procedure DumpImageBlobToDisk (ImageID: integer);
var
  info: TWhatINeedToKnow;
  Stream: TMemoryStream;
begin
  info := TWhatINeedToKnow.Create;
  Stream := TMemoryStream.Create;

  try
    info.Database := s3db;  // Replace with your active TSQLite3Connection
    info.TableToWorkWith := 'ComponentImages';
    info.FieldForBlob := 'RawData';
    info.FieldForID := 'ImageID';
    info.RecordID := ImageID;
    info.CompressedContent := True;  // Make sure this matches what was used on write

    DbToStream(info, Stream);
    Stream.Position := 0;
    Stream.SaveToFile('R:\Test.jpg');

    Application.MessageBox('Image written to R:\Test.jpg', 'Export OK', MB_OK);
  finally
    Stream.Free;
    info.Free;
  end;
end;

function TForm1.ConvertBMPClipboardToOptimalFormat (out FileFormat: string): TMemoryStream;
var
  bmp: TBitmap;
  intfImg: TFPMemoryImage;
  x, y: integer;
  reader: TFPReaderBMP;
  writerJPEG: TFPWriterJPEG;
  writerPNG: TFPWriterPNG;
  jpegStream, pngStream: TMemoryStream;
begin
  bmp := TBitmap.Create;
  try
    Clipboard.AssignTo(bmp);

    // Convert to FCL image
    intfImg := TFPMemoryImage.Create(bmp.Width, bmp.Height);
    reader := TFPReaderBMP.Create;
    try
      // Assign bitmap to interface image
      intfImg.Assign(bmp);


      // Prefer JPEG if no alpha is present
      writerJPEG := TFPWriterJPEG.Create;
      jpegStream := TMemoryStream.Create;
      try
        writerJPEG.CompressionQuality := 85; // Tunable
        intfImg.SaveToStream(jpegStream, writerJPEG);
        jpegStream.Position := 0;
        Result := jpegStream;
      finally
        writerJPEG.Free;
        FileFormat := 'JPEG';
        // jpegStream is returned
      end;
    finally
      reader.Free;
      intfImg.Free;
    end;
  finally
    bmp.Free;
  end;
end;

function GetImageDimensions (Stream: TMemoryStream): TPoint;
var
  pic: TPicture;
begin
  Result := Point(0, 0); // fallback
  pic := TPicture.Create;
  try
    pic.LoadFromStream(Stream);
    Result := Point(pic.Width, pic.Height);
  finally
    pic.Free;
  end;
end;

procedure TForm1.SaveStreamToDatabase (InStream: tMemoryStream; Ext: string);
begin
  InStream.SaveToFile('r:\Test.' + Ext);
end;

function TForm1.GetImageDimensions (Stream: TMemoryStream): TPoint;
var
  pic: TPicture;
begin
  Result := Point(0, 0); // fallback
  pic := TPicture.Create;
  try
    pic.LoadFromStream(Stream);
    Result := Point(pic.Width, pic.Height);
  finally
    pic.Free;
  end;
end;


function TForm1.ConvertToSupportedImage (out Stream: tMemoryStream; out ImgFmt: string): boolean;
begin
  // Convert the clipboard to PNG or JPEG.
  Result := True;
  if Clipboard.HasFormatName('PNG') then begin
    stream := TMemoryStream.Create;
    Clipboard.GetFormat(Clipboard.FindFormatID('PNG'), stream);
    stream.Position := 0;
    ImgFmt := 'PNG';
  end else if Clipboard.HasFormatName('image/bmp') then begin
    stream := ConvertBMPClipboardToOptimalFormat(ImgFmt);
    Stream.Position := 0;
  end else begin
    ShowMessage('Unsupported clipboard image format.');
    Result := False;
  end;
end;

procedure TForm1.mnuPasteImageClick (Sender: TObject);
var
  ActiveLB: TListBox;
  ActivePage: TTabSheet;
  bmp: TBitmap;
  BuildSheetValidSelect, CustomSheetValidSelect: boolean;
  FormatID, i: integer;
  ImgFmt, sql: string;
  Info: TWhatINeedToKnow;
  jpegStream, Stream: TMemoryStream;
  jpg: TJPEGImage;
  q: TSQLQuery;
  sl: TStringList;
  Dims: tPoint;
begin
  if ConvertToSupportedImage(Stream, ImgFmt) then begin
    // Figure out if we've got a valid selection in a listbox depending on the tab we're in
    ActiveLB := nil;
    ActivePage := PageControl1.ActivePage;
    BuildSheetValidSelect := (ActivePage = tsBuildSheet) and (lbBuildList.ItemIndex >= 0);
    if BuildSheetValidSelect then begin
      ActiveLB := lbBuildList;
    end else begin
      // We need to set CustomSheetValidSelect just in case a tab does not have content in the LB
      ActiveLB := TListBox(FindAnyComponent(ActivePage, 'lb__' + SafeComponentName(ActivePage.Caption) + '__List'));
      CustomSheetValidSelect := (ActivePage <> tsBuildSheet) and (ActiveLB.ItemIndex >= 0);
    end;

    // Prepare Info object
    Info := TWhatINeedToKnow.Create;
    Info.Database := s3db;  // <-- replace with your actual object
    Info.TableToWorkWith := 'ComponentImages';
    Info.FieldForBlob := 'RawData';
    Info.FieldForID := 'ImageID';
    Info.RecordID := -1;  // insert mode
    Info.CompressedContent := True;

    Dims := GetImageDimensions(Stream);

    StreamToDB(Info, stream);

    sql := Format('update %s set ComponentType=:CompType, ComponentID=:CompID, Filename=:FileName, Width=:Width, Height=:Height, Format=:Format, OriginalFileName=:Filename where ImageID=:ImageID', [Info.TableToWorkWith]);
    q := NewQuery(S3DB);
    q.SQL.Text := sql;
    q.ParamByName('ImageID').AsInteger := Info.RecordID;
    if ActiveLB = lbBuildList then begin
      q.ParamByName('CompType').AsString := ActivePage.Caption;
    end else begin
      q.ParamByName('CompType').AsString := SafeComponentName(ActivePage.Caption);
    end;
    q.ParamByName('CompID').AsInteger := O2I(ActiveLB.Items.Objects[ActiveLB.ItemIndex]);
    q.ParamByName('Filename').AsString := 'Clipboard_' + SafeComponentName(ActivePage.Caption) + '_' + IntToStr(info.RecordID) + '.jpg';
    q.ParamByName('Format').AsString := ImgFmt;
    q.ParamByName('Width').AsInteger := Dims.X;
    q.ParamByName('Height').AsInteger := Dims.Y;
    q.ExecSQL;
    EndQuery(q);

    Info.Free;
    Stream.Free;
    ReloadImagesOnScreen;

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

function TForm1.GetBuildIdForComponent (ComponentID: integer; Component: string): integer;
(*
@AI:summary: Retrieves the BuildID that a specific component is assigned to, based on component type and ID.
@AI:params: ComponentID: The numeric ID of the component in its device table.
@AI:params: Component: The short name of the component type (e.g., 'Motherboards').
@AI:returns: The BuildID the component is assigned to, or -1 if unassigned.
*)
var
  q: TSQLQuery;
  sql: string;
  res: integer;
begin
  q := NewQuery(s3db);
  sql := 'SELECT BuildID FROM BuildComponents WHERE Component = :comp AND ComponentID = :cid';
  q.SQL.Text := sql;
  q.ParamByName('comp').AsString := Component;
  q.ParamByName('cid').AsInteger := ComponentID;
  q.Open;
  res := -1;
  if not q.EOF then begin
    res := q.FieldByName('BuildID').AsInteger;
  end;
  EndQuery(q);
  Result := res;
end;

procedure TForm1.AssignBuildButtonClick (Sender: TObject);
(*
@AI:summary: Toggles a component's assignment to the selected build. Inserts, removes, or moves the component depending on its current association.
@AI:params: Sender: The button clicked to initiate the toggle.
@AI:returns: None.
*)
var
  TabShortName, Prefix, BuildName, SQL: string;
  ListBox: TListBox;
  Button: TButton;
  ComponentID, BuildID, AssignedBuildID: integer;
  q: TSQLQuery;
begin
  if lbBuildList.ItemIndex = -1 then begin
    Exit;
  end;

  TabShortName := SafeComponentName(PageControl1.ActivePage.Caption);
  Prefix := TabShortName + '__BuildAssign__';

  ListBox := TListBox(FindAnyComponent(PageControl1.ActivePage, 'lb__' + TabShortName + '__List'));
  Button := TButton(Sender);
  if (ListBox = nil) or (ListBox.ItemIndex = -1) then begin
    Exit;
  end;

  ComponentID := O2I(ListBox.Items.Objects[ListBox.ItemIndex]);
  BuildID := O2I(lbBuildList.Items.Objects[lbBuildList.ItemIndex]);
  AssignedBuildID := GetBuildIDForComponent(ComponentID, TabShortName);
  BuildName := GetBuildNameForID(BuildID);

  if AssignedBuildID = -1 then begin
    // INSERT new link
    SQL := 'INSERT INTO BuildComponents (BuildID, Component, ComponentID) VALUES (:b, :c, :i)';
    q := NewQuery(S3DB);
    q.SQL.Text := SQL;
    q.ParamByName('b').AsInteger := BuildID;
    q.ParamByName('c').AsString := TabShortName;
    q.ParamByName('i').AsInteger := ComponentID;
    q.ExecSQL;
    EndQuery(q);
  end else if AssignedBuildID = BuildID then begin
    // DELETE existing link
    SQL := 'DELETE FROM BuildComponents WHERE BuildID = :b AND Component = :c AND ComponentID = :i';
    q := NewQuery(S3DB);
    q.SQL.Text := SQL;
    q.ParamByName('b').AsInteger := BuildID;
    q.ParamByName('c').AsString := TabShortName;
    q.ParamByName('i').AsInteger := ComponentID;
    q.ExecSQL;
    EndQuery(q);
  end else begin
    // Assigned to a different build — confirm move
    if MessageDlg(
      'This component is already assigned to "' + GetBuildNameForID(AssignedBuildID) + '".' + LineEnding +
      'Move it to "' + BuildName + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then begin
      SQL := 'UPDATE BuildComponents SET BuildID = :b WHERE Component = :c AND ComponentID = :i';
      q := NewQuery(S3DB);
      q.SQL.Text := SQL;
      q.ParamByName('b').AsInteger := BuildID;
      q.ParamByName('c').AsString := TabShortName;
      q.ParamByName('i').AsInteger := ComponentID;
      q.ExecSQL;
      EndQuery(q);
    end;
  end;

  // TODO: Log assignment change to memo here

  UpdateBuildAssignmentStatus(TabShortName);
  ReloadImagesOnScreen;
end;

procedure TForm1.ThumbnailClick (Sender: TObject);
const
  CompImages = 'select ComponentType,ComponentID from ComponentImages where ImageID=:ImageID';
var
  ActiveLB: TListBox;
  ActiveTab: TTabSheet;
  ImageID: integer;
  q: TSQLQuery;
  ComponentType: string;
  ComponentID: integer;
  i: integer;
begin
  //  application.MessageBox('Clickededed', '', MB_OK);
  // Determine what Component and ComponentID this is so we can go find the appropriate details
  // - Query the table for the ComponentType and ComponentID
  // - Search through the tablist for the "safe" tab caption.  (Build List never comes into play since we're going to a component to manage)
  // - If we get a hit, switch to that tab, and we'll have to wait for the change to take effect on the PageControl.
  // - Once we're done and the listbox is populated, seek the itemindex of the object for what ComponentID is

  ImageID := TImage(Sender).Tag;
  q := NewQuery(s3db);
  q.SQL.Text := CompImages;
  q.ParamByName('ImageID').AsInteger := ImageID;
  q.Open;
  ComponentID := -1;
  if not q.EOF then begin
    ComponentType := q.FieldByName('ComponentType').AsString;
    ComponentID := q.FieldByName('ComponentID').AsInteger;
  end;
  EndQuery(q);

  if ComponentID <> -1 then begin
    // For the length of time it'll take to go through the tabs, a for loop is acceptable
    for i := 1 to PageControl1.PageCount - 1 do begin
      if SafeComponentName(PageControl1.Page[i].Caption) = ComponentType then begin
        PageControl1.ActivePageIndex := i;
        PageControl1Change(nil);
        ActiveTab := PageControl1.ActivePage;
        ActiveLB := TListBox(FindAnyComponent(ActiveTab, 'lb__' + SafeComponentName(ActiveTab.Caption) + '__List'));
        if ActiveLB.ItemIndex <> ActiveLB.Items.IndexOfObject(i2o(ComponentID)) then begin
          ActiveLB.ItemIndex := ActiveLB.Items.IndexOfObject(i2o(ComponentID));
          ActiveLB.Click;
        end;
      end;
    end;
  end else begin
    Application.MessageBox('Warning: This image no longer exists in the database.  Aborting.', 'Aborting', MB_OK + MB_ICONEXCLAMATION);
  end;

end;


function TForm1.GetBuildNameForID (ID: integer): string;
(*
@AI:summary: Retrieves the human-readable name of a build given its BuildID.
@AI:params: ID: The BuildID to look up.
@AI:returns: The BuildName corresponding to the specified BuildID.
*)
var
  q: TSQLQuery;
  sql: string;
begin
  q := NewQuery(s3db);
  sql := 'SELECT BuildName FROM BuildList WHERE BuildID = :b';
  q.SQL.Text := sql;
  q.ParamByName('b').AsInteger := ID;
  q.Open;
  Result := q.FieldByName('BuildName').AsString;
  EndQuery(q);
end;

procedure TForm1.UpdateBuildAssignmentStatus (const TabShortName: string);
(*
@AI:summary: Updates the status of a build assignment based on the provided tab short name.
@AI:params: TabShortName: The short name of the tab used to identify the build assignment to be updated.
@AI:returns:
*)
var
  ListBox: TListBox;
  Panel: TPanel;
  LabelStatus: TLabel;
  ButtonAction: TButton;
  SelectedComponentID, BuildID, AssignedBuildID: integer;
  AssignedBuildName: string;
  Prefix: string;
  ColorPanel: TPanel;
begin
  Prefix := TabShortName + '__BuildAssign__';
  ListBox := TListBox(FindAnyComponent(PageControl1.ActivePage, 'lb__' + TabShortName + '__List'));
  Panel := TPanel(FindAnyComponent(PageControl1.ActivePage, SafeComponentName(Prefix + 'Panel')));
  LabelStatus := TLabel(FindAnyComponent(PageControl1.ActivePage, SafeComponentName(Prefix + 'Label')));
  ButtonAction := TButton(FindAnyComponent(PageControl1.ActivePage, SafeComponentName(Prefix + 'Button')));

  if (ListBox = nil) or (Panel = nil) or (LabelStatus = nil) or (ButtonAction = nil) then begin
    Exit;
  end;
  if ListBox.ItemIndex = -1 then begin
    Exit;
  end;

  SelectedComponentID := O2I(ListBox.Items.Objects[ListBox.ItemIndex]);
  BuildID := O2I(lbBuildList.Items.Objects[lbBuildList.ItemIndex]);

  AssignedBuildID := GetBuildIDForComponent(SelectedComponentID, TabShortName);
  AssignedBuildName := GetBuildNameForID(AssignedBuildID);        // Ditto

  // Update label
  if AssignedBuildID = -1 then begin
    LabelStatus.Caption := 'Currently assigned to:' + LineEnding + '(Unassigned)';
  end else begin
    LabelStatus.Caption := 'Currently assigned to:' + LineEnding + AssignedBuildName;
  end;

  // Update button
  if AssignedBuildID = -1 then begin
    ButtonAction.Caption := 'Assign to Build';
    AssignButtonFlashTimer.Enabled := True;
  end else if AssignedBuildID = BuildID then begin
    ButtonAction.Caption := 'Remove from Build';
    AssignButtonFlashTimer.Enabled := False;
    Panel.Color := clDefault;
  end else begin
    ButtonAction.Caption := 'Move from ' + AssignedBuildName + LineEnding + 'to current build';
    AssignButtonFlashTimer.Enabled := False;
    Panel.Color := clDefault;
  end;
end;

function RandomChar (Size: integer): string;
var
  rs: string;
  x: integer;
begin
  rs := '';
  for x := 1 to Size do begin
    rs := rs + chr(Random(26) + Ord('A'));
  end;
  Result := rs;
end;

procedure TForm1.PrepareIdleDeletes (ParentComponent: tControl);
var
  x: integer;
  pc: TControl;
begin
  //  IdleDeleteObjects
  for x := 0 to ParentComponent.ComponentCount - 1 do begin
    pc := TControl(ParentComponent.Components[x]);
    if IdleDeleteObjects.IndexOf(TObject(pc)) = -1 then begin
      pc.Name := pc.Name + '_Delete_' + randomchar(16);
      IdleDeleteObjects.Add(TObject(ParentComponent.Components[x]));
      if tControl(ParentComponent.Components[x]).ComponentCount > 0 then begin
        tControl(ParentComponent.Components[x]).Visible := False;
        PrepareIdleDeletes(tControl(ParentComponent.Components[x]));
      end;
    end;
  end;
end;

procedure TForm1.PerformIdleDeletes;
var
  x: integer;
  twc: tControl;
begin
  for x := IdleDeleteObjects.Count - 1 downto 0 do begin
    twc := tControl(IdleDeleteObjects.Items[x]);
    if assigned(twc) then begin
      if tControl(twc) is TEdit then begin
        TEdit(twc).Free;
      end else if twc is TComboBox then begin
        TComboBox(twc).Free;
      end else if twc is TGroupBox then begin
        TGroupBox(twc).Free;
      end else if twc is TPanel then begin
        TPanel(twc).Free;
      end else if tControl(twc) is TImage then begin
        TImage(twc).Picture.Clear;
        TImage(twc).Free;
      end else begin
        MessageDlg('Error', 'Unknown Component Type: ' + twc.Name, TMsgDlgType.mtError, [mbOK], '');
      end;
    end;
  end;
  IdleDeleteObjects.Clear;
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

  ImageContainer.Parent := PageControl1.ActivePage;
  // Check if this is a dynamic tab by looking at INI or _T suffix
  DynamicTab := PageControl1.ActivePage.Name.EndsWith('_T');
  if not DynamicTab then begin
    Ini := TIniFile.Create('Structure.ini');
    try
      DynamicTab := Ini.ValueExists('ORDER', ActivePageName);
    finally
      Ini.Free;
    end;
  end;

  if not DynamicTab then begin
  end;

  // Skip processing if this is not a dynamic tab
  if DynamicTab then begin
    // Get the table name (remove spaces from tab caption)
    ShortName := StringReplace(PageControl1.ActivePage.Caption, ' ', '', [rfReplaceAll]);
    TableName := 'Device_' + ShortName;

    // Find the ListBox in the correct group box within the active tab
    //  ListBox := tListbox(FindAnyComponent(PageControl1.ActivePage, ShortName));
    ListBox := TListBox(FindAnyComponent(PageControl1.ActivePage, 'lb__' + ShortName + '__List'));

    if Assigned(ListBox) then begin
      LoadDataIntoListBox(ListBox, TableName);
      if ListBox.Count > 0 then begin
        if ListBox.ItemIndex <> max(0, ListBox.ItemIndex) then begin
          ListBox.ItemIndex := max(0, ListBox.ItemIndex);
          ListBox.Click;
        end;
      end;

    end else begin
      Application.MessageBox(PChar('ListBox not found for ' + TableName), 'Error', MB_OK);
    end;
    // Toggle the visibility of the component assignment to build panel
    tPanel(FindAnyComponent(Form1, SafeComponentName(ShortName + '__BuildAssign__Panel'))).Visible := lbBuildList.ItemIndex >= 0;
  end;
  ReloadImagesOnScreen;
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
    if lbBuildList.ItemIndex = -1 then begin
      Query.SQL.Text := 'SELECT DeviceID, QRCode, Title FROM ' + TableName + ' ORDER BY upper(Title),QRCode;';
    end else begin
      Query.Sql.Text := 'select DeviceID, QRCode, Title FROM ' + TableName + ' order by DeviceID in (select ComponentID from BuildComponents where Component=:Component and BuildID=:BuildID) desc,lower(Title),QRCode;';
      Query.ParamByName('Component').AsString := SafeComponentName(PageControl1.ActivePage.Caption);
      Query.ParamByName('BuildID').AsInteger := o2i(lbBuildList.Items.Objects[lbBuildList.ItemIndex]);
    end;

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

procedure TForm1.CreateBuildAssignmentPanel (Frame: TFrame1; TabShortName: string);
(*
@AI:summary: Adds a right-aligned panel to Frame1 with build assignment label, button, and a memo log.
@AI:params: Frame: The TFrame1 container to embed the controls into.
@AI:params: TabShortName: The component name (e.g., 'Motherboards') used for dynamic naming.
@AI:returns: No result. All components are added directly to Frame1.
*)
var
  AssignPanel: TPanel;
  AssignLabel: TLabel;
  AssignButton: TButton;
  AssignMemo: TMemo;
  Prefix: string;
begin
  Prefix := TabShortName + '__BuildAssign__';

  AssignPanel := TPanel.Create(Frame);
  AssignPanel.Name := SafeComponentName(Prefix + 'Panel');
  AssignPanel.Parent := Frame;
  AssignPanel.Align := alRight;
  AssignPanel.Width := trunc(220 * 1.5);
  AssignPanel.BevelOuter := bvNone;

  AssignLabel := TLabel.Create(AssignPanel);
  AssignLabel.Name := SafeComponentName(Prefix + 'Label');
  AssignLabel.Parent := AssignPanel;
  AssignLabel.Align := alTop;
  AssignLabel.Alignment := taRightJustify;
  AssignLabel.Font.Style := [fsBold];
  AssignLabel.Caption := 'Currently assigned to:' + LineEnding + '(Unassigned)';
  AssignLabel.AutoSize := False;
  AssignLabel.Height := 36;

  AssignButton := TButton.Create(AssignPanel);
  AssignButton.Name := SafeComponentName(Prefix + 'Button');
  AssignButton.Parent := AssignPanel;
  AssignButton.Align := alTop;
  AssignButton.Caption := 'Assign to Build';
  AssignButton.Height := 30;
  AssignButton.OnClick := @AssignBuildButtonClick;

  AssignMemo := TMemo.Create(AssignPanel);
  AssignMemo.Name := SafeComponentName(Prefix + 'Memo');
  AssignMemo.Parent := AssignPanel;
  AssignMemo.Align := alClient;
  AssignMemo.ReadOnly := True;
  AssignMemo.WordWrap := True;
  AssignMemo.ScrollBars := ssVertical;
  AssignMemo.Lines.Text :=
    'History:' + LineEnding +
    '- Component created: <timestamp placeholder>' + LineEnding +
    '- Build assignment changes will appear here.';

end;

procedure TForm1.AddGlobalFieldsToFrame (Frame: TFrame1; ComponentName: string);
(*
@AI:summary: This function likely adds global fields to a specified frame component.
@AI:params: Frame: The frame to which global fields will be added.
@AI:params: ComponentName: The name of the component for which global fields are being added.
@AI:returns:
*)
{ TODO -cBUG : This routine is not looking at component overrides, such as CLASS type -- Global is defined as a TEXT, but some components have a Combo defined. }
var
  Q, InsertQ: TSQLQuery;
  FieldName, FieldLabel, FieldType, ComboValues: string;
  FieldY: integer;
  LabelCtrl: TLabel;
  EditCtrl: TEdit;
  ComboCtrl: TComboBox;
  MemDB: TSQLite3Connection;
  MemTrans: TSQLTransaction;
  SQL: string;
const
  LineDisplacement = 2;
begin
  // Setup in-memory SQLite connection
  MemDB := TSQLite3Connection.Create(nil);
  MemDB.DatabaseName := ':memory:';
  MemTrans := TSQLTransaction.Create(nil);
  MemTrans.DataBase := MemDB;
  MemDB.Transaction := MemTrans;
  MemDB.Open;

  // Recreate LayoutMap schema
  Q := NewQuery(S3DB);
  try
    Q.SQL.Text := 'SELECT sql FROM sqlite_master WHERE type = ''table'' AND name = ''LayoutMap''';
    Q.Open;
    if not Q.EOF then begin
      SQL := Q.Fields[0].AsString;
      EndQuery(Q); // Close before reuse

      Q := NewQuery(MemDB);
      Q.SQL.Text := SQL;
      Q.ExecSQL;
    end;
  finally
    EndQuery(Q);
  end;

  Q := NewQuery(S3DB);
  Q.SQL.Text := 'SELECT * FROM LayoutMap WHERE Component IN (''GLOBAL'', :Comp)';
  Q.ParamByName('Comp').AsString := ComponentName;
  Q.Open;
  InsertQ := NewQuery(MemDB);
  try
    while not Q.EOF do begin
      InsertQ.SQL.Text := 'INSERT INTO LayoutMap VALUES (:Origin, :Component, :FieldName, :FieldLabel, :GroupName, :SortOrder, :ComponentType, :ComboValues)';
      InsertQ.ParamByName('Origin').AsString := Q.FieldByName('Origin').AsString;
      InsertQ.ParamByName('Component').AsString := Q.FieldByName('Component').AsString;
      InsertQ.ParamByName('FieldName').AsString := Q.FieldByName('FieldName').AsString;
      InsertQ.ParamByName('FieldLabel').AsString := Q.FieldByName('FieldLabel').AsString;
      InsertQ.ParamByName('GroupName').AsString := Q.FieldByName('GroupName').AsString;
      InsertQ.ParamByName('SortOrder').AsInteger := Q.FieldByName('SortOrder').AsInteger;
      InsertQ.ParamByName('ComponentType').AsString := Q.FieldByName('ComponentType').AsString;
      InsertQ.ParamByName('ComboValues').AsString := Q.FieldByName('ComboValues').AsString;
      InsertQ.ExecSQL;
      Q.Next;
    end;
  finally
    EndQuery(Q);
    EndQuery(InsertQ);
  end;

  q := NewQuery(MemDB);
  // Remove overridden global rows
  Q.SQL.Text := 'DELETE FROM LayoutMap WHERE Origin = ''G'' AND FieldName IN ' +
    '(SELECT FieldName FROM LayoutMap WHERE Origin = ''C'' AND Component = :Comp)';
  Q.ParamByName('Comp').AsString := ComponentName;
  Q.ExecSQL;

  // Normalize tag to G for unified rendering logic
  Q.SQL.Text := 'UPDATE LayoutMap SET Origin = ''G'' WHERE Component = :Comp';
  Q.ParamByName('Comp').AsString := ComponentName;
  Q.ExecSQL;
  EndQuery(q);

  FieldY := LineDisplacement;
  Q := NewQuery(MemDB);
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
        ComboCtrl.OnDropDown := @cboPopulateCombo;
        ComboCtrl.OnSelect := @cboItemSelected;

        GlobalComponentList.AddObject(ComboCtrl.Name + '=' + ComponentName + '.' + FieldName, ComboCtrl);
        Inc(FieldY, ComboCtrl.Height + LineDisplacement);
      end else if lowercase(FieldType) = 'integer' then begin
        ComboCtrl := TComboBox.Create(Frame.GlobalDetails);
        ComboCtrl.Parent := Frame.GlobalDetails;
        ComboCtrl.Left := 250;
        ComboCtrl.Top := FieldY;
        ComboCtrl.Width := 250;
        ComboCtrl.Name := SafeComponentName(ComponentName + '__' + FieldName);
        ComboCtrl.OnDropdown := @cboPopulateNumeric;
        ComboCtrl.OnSelect := @cboItemSelected;

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
    MemDB.Close;
    MemTrans.Free;
    MemDB.Free;
  end;
  CreateBuildAssignmentPanel(Frame, SafeComponentName(ComponentName));
end;

procedure TForm1.CreateTab (ComponentName: string);
(*
@AI:summary: When called, this function will create the tab and sub components required to display the component list.  This does not deal with the design-time built Build List tab or menus.
@AI:params: ComponentName: This is the type of component that this tab is responsible for displaying, such as motherboards, sound cards, etc.
@AI:returns:
@AI:notes: If asked, to add events and triggers to the different components created, the CreateTab function is where it's at.
*)
var
  Tab: TTabSheet;
  LeftPanel: TGroupBox;
  ItemList: TListBox;
  Frame1: TFrame1;
  Frame2: TFrame2;
  Q: TSQLQuery;
  GroupName, FieldName: string;
  FieldLabel: TLabel;
  LastGroupName: string;
  FieldY: integer;
  FrameCount: integer;
  FieldType, ComboValues, FieldLabelText: string;
  Combo: TComboBox;
  Spin: tComboBox;
  Edit: TEdit;
  GlobalY: integer;
begin
  Tab := TTabSheet.Create(PageControl1);
  Tab.PageControl := PageControl1;
  Tab.Caption := ComponentName;
  Tab.Name := 'ts' + SafeComponentName(ComponentName);

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
  ItemList.Sorted := False;
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
        Frame2.Name := SafeComponentName(ComponentName + '_' + GroupName);
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
      FieldLabel.Name := SafeComponentName('label_' + ComponentName + '_' + GroupName + '_' + FieldName);
      FieldLabel.Parent := Frame2.CompDetails;
      FieldLabel.Caption := q.FieldByName('FieldLabel').AsString;
      FieldLabel.Left := 8;
      FieldLabel.Top := FieldY;

      FieldName := Q.FieldByName('FieldName').AsString;
      FieldLabelText := Q.FieldByName('FieldLabel').AsString;
      GroupName := Q.FieldByName('GroupName').AsString;
      FieldType := Q.FieldByName('ComponentType').AsString;
      ComboValues := Q.FieldByName('ComboValues').AsString;

      // Component creation
      if LowerCase(FieldType) = 'combo' then begin
        Combo := TComboBox.Create(Frame2.CompDetails);
        Combo.Parent := Frame2.CompDetails;
        Combo.Left := 8;
        Combo.Top := FieldY + FieldLabel.Height + 4;
        Combo.Width := 200;
        Combo.Name := SafeComponentName(ComponentName + '__' + FieldName);
        Combo.OnDropDown := @cboPopulateCombo;
        Combo.OnSelect := @cboItemSelected;

        // Add static combo values from LayoutMap
        if ComboValues <> '' then begin
          Combo.Items.Text := ComboValues;
        end;
        Inc(FieldY, FieldLabel.Height + Combo.Height + 12);

        // Add to registry
        GlobalComponentList.AddObject(Combo.Name + '=' + ComponentName + '.' + FieldName, Combo);
      end else if lowercase(FieldType) = 'integer' then begin
        Spin := TComboBox.Create(Frame2.CompDetails);
        Spin.Parent := Frame2.CompDetails;
        Spin.Left := 8;
        Spin.Top := FieldY + FieldLabel.Height + 4;
        Spin.Width := 200;
        Spin.Name := SafeComponentName(ComponentName + '__' + FieldName);
        Inc(FieldY, FieldLabel.Height + Spin.Height + 12);
        Spin.OnDropDown := @cboPopulateNumeric;
        Spin.OnSelect := @cboItemSelected;

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
  if (Sender is TListBox) then begin
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
    UpdateBuildAssignmentStatus(TabShortName);
    ReloadImagesOnScreen;
  end;
end;

procedure TForm1.PopulateSpecsPane (DeviceID: integer; const TabShortName: string);
(*
@AI:summary: This is an OVERLOADED function.  Based on the tab name (Spaces removed) populate the tEdit/tCombo fields placed on the form on this tab.
@AI:params: DeviceID: The unique identifier for the device whose specifications are to be populated.
@AI:params: TabShortName: The short name of the tab where the specifications will be displayed.
@AI:returns:
*)
var
  Query: TSQLQuery;
  FieldIndex: integer;
  FieldName, ComponentName: string;
  SubjectComponent: TWinControl;
  CI: integer;
  FieldValue: string;
begin
  // Converting to the GlobalComponents stuffs

  // Run the query
  Query := NewQuery(S3DB);
  try
    Query.SQL.Text := 'SELECT * FROM Device_' + TabShortName + ' WHERE DeviceID = :id';
    Query.ParamByName('id').AsInteger := DeviceID;
    Query.Open;

    if not Query.EOF then begin
      for FieldIndex := 0 to Query.Fields.Count - 1 do begin
        FieldName := Query.Fields[FieldIndex].FieldName;

        ComponentName := TabShortName + '__' + FieldName;
        CI := GlobalComponentList.IndexOfName(ComponentName);
        if length(Query.Fields[FieldIndex].AsString) = 0 then begin
          FieldValue := '';
        end else begin
          FieldValue := Query.Fields[FieldIndex].Value;
        end;
        if ci <> -1 then begin
          SubjectComponent := TWinControl(GlobalComponentList.Objects[CI]);
          if SubjectComponent is TEdit then begin
            TEdit(SubjectComponent).Text := FieldValue;
            TEdit(SubjectComponent).OnExit := @ComponentExit;
          end else if SubjectComponent is TComboBox then begin
            TComboBox(SubjectComponent).Text := FieldValue;
            TComboBox(SubjectComponent).OnExit := @ComponentExit;
          end;
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
  if assigned(ActiveTab) then begin

    // Strip spaces from tab caption to match the expected naming convention
    StrippedTabName := StringReplace(ActiveTab.Caption, ' ', '', [rfReplaceAll]);

    // Check if this is a dynamic tab
    IsDynamicTab := ActiveTab.Name.EndsWith('_T');
    if not IsDynamicTab then begin
      Ini := TIniFile.Create('Structure.ini');
      IsDynamicTab := Ini.ValueExists('ORDER', ActiveTab.Caption);
      Ini.Free;
    end;

    // If it's not dynamic, exit (static tabs like "Build List" don't have specs)
    if IsDynamicTab then begin

      // Find the dynamically created Specs group box in this tab
      SpecsGroup := TGroupBox(ActiveTab.FindComponent('gb' + StrippedTabName + 'Specs'));
      if assigned(SpecsGroup) then begin
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

          if Query.RecordCount > 0 then begin
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
          end; // if Query.RecordCount
        finally
          EndQuery(Query);
        end;
      end; // if assigned(SpecsGroup)
    end; // if IsDynamicTab
  end; // if assigned(ActiveTab)
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
  { TODO : Ensure uniqueness before insert -- Currently will not fail politely }
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
          ListBox := TListBox(FindAnyComponent(TabSheet, 'lb__' + ShortName + '__List'));
          if Assigned(ListBox) then begin
            LoadDataIntoListBox(ListBox, TableName);
            MatchIndex := ListBox.Items.IndexOf(QRString + '- ' + Title);
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
