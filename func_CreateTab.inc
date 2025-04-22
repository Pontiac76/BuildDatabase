

function SafeComponentName (Raw: string): string;
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

