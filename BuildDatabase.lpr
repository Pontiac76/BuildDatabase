program BuildDatabase;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  lazcontrols,
  runtimetypeinfocontrols,
  frmMain,
  DatabaseManager,
  MiscFunctions,
  UIManager,
  TabGrouping,
  ComponentDetails,
  frmCamera;

  {$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(tCamera,CameraForm);
  Application.Run;
end.
