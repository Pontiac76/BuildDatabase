unit frmDebug;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,StdCtrls,ExtCtrls;

type

  { TDebugForm }

  TDebugForm = class(TForm)
    LabeledEdit1:TLabeledEdit;
    LabeledEdit2:TLabeledEdit;
    LabeledEdit3:TLabeledEdit;
    LabeledEdit4:TLabeledEdit;
    LabeledEdit5:TLabeledEdit;
    LabeledEdit6:TLabeledEdit;
    MasterPanel:TPanel;
    GlobalDetails:TPanel;
    MasterHorizontalScroll:TScrollBox;
  private
  public

  end;

var
  DebugForm: TDebugForm;

implementation

uses MiscFunctions;

{$R *.lfm}

{ TDebugForm }


end.

