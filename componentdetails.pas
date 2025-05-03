(*
@AI:unit-summary: This Pascal unit defines a graphical user interface component, specifically a frame (TFrame2) that contains a panel for a group title and a scrollable box for displaying component details. Its primary responsibility is to manage the layout and presentation of these UI elements within an application.
*)
unit ComponentDetails;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,ExtCtrls;

type

  { TFrame2 }

  TFrame2 = class(TFrame)
    CompGroupTitle:TPanel;
    CompDetails:TScrollBox;
  private

  public

  end;

implementation

{$R *.lfm}

end.

