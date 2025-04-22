unit MiscFunctions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils,StdCtrls,Forms, LCLIntf, LCLType, Controls, Math;

function NoSpaces(stIn:string):string;
function NoDoubleSpace(stIn:string):string;
function O2I (obj: TObject): integer;
function I2O (Value: integer): TObject;
function ListObject(lb:TListBox):integer;
procedure SizeForm(frm, relativeTo: TForm; Scale: Byte);

implementation

const CRLF=chr(13)+chr(10);


procedure SizeForm(frm, relativeTo: TForm; Scale: Byte);
var
  TargetMonitor: TMonitor;
  ScaledWidth, ScaledHeight: Integer;
begin
  // Clamp Scale between 50% and 100%
  Scale := Min(100, Max(50, Scale));

  if Assigned(relativeTo) then
    TargetMonitor := Screen.MonitorFromWindow(HWND(relativeTo.Handle))
  else
    TargetMonitor := Screen.Monitors[0];

  ScaledWidth := (TargetMonitor.Width * Scale) div 100;
  ScaledHeight := (TargetMonitor.Height * Scale) div 100;

  frm.Width := ScaledWidth;
  frm.Height := ScaledHeight;
  frm.Left := TargetMonitor.Left + ((TargetMonitor.Width - frm.Width) div 2);
  frm.Top := TargetMonitor.Top + ((TargetMonitor.Height - frm.Height) div 2);
end;

function NoSpaces(stIn:string):string;
begin
  result:=StringReplace(stIn,' ','',[rfReplaceAll]);
end;

function NoDoubleSpace(stIn:string):string;
begin
  while Pos(crlf+crlf,stin)<>0 do
    stIn:=StringReplace(stIn,crlf+crlf,crlf,[rfReplaceAll]);
  result:=trim(stIn);
end;

// Object to Integer routine
function O2I (obj: TObject): integer;
var
  ptr: Pointer;
begin
  ptr := Pointer(obj);
  Result := integer(ptr);
end;

// Integer to Object routine
function I2O (Value: integer): TObject;
var
  ptr: Pointer;
begin
  ptr := Pointer(Value);
  Result := TObject(ptr);
end;

function ListObject(lb:TListBox):integer;
begin
  result:=-1;
  if lb.ItemIndex<>-1 then begin
    result:=o2i(lb.Items.Objects[lb.ItemIndex]);
  end;
end;

end.

