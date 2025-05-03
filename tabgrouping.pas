(*
@AI:unit-summary: This Pascal unit defines a graphical user interface component, specifically a frame (TFrame1), which contains a panel for global details and a scroll box for grouping elements, suggesting its role in organizing and displaying grouped information within a larger application.
*)
unit TabGrouping;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,ExtCtrls,ComponentDetails;

type

  { TFrame1 }

  TFrame1 = class(TFrame)
    GlobalDetails:TPanel;
    sbGroupScroll:TScrollBox;
  private

  public

  end;

implementation

{$R *.lfm}

{ TFrame1 }


end.

