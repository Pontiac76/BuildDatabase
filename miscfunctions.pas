(*
@AI:unit-summary: This Pascal unit provides utility functions for string manipulation, object-integer conversions, and form resizing, primarily aimed at enhancing user interface elements and managing object references in a list box context.
*)
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
(*
@AI:summary: Adjusts the size of a form based on a specified scaling factor relative to another form.
@AI:params: frm: The form whose size will be adjusted.
@AI:params: relativeTo: The form that serves as the reference for scaling.
@AI:params: Scale: The scaling factor to apply to the size of the form.
@AI:returns:
*)
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
(*
@AI:summary: This function removes all spaces from the input string.
@AI:params: stIn: The input string from which spaces will be removed.
@AI:returns: A string that contains the input string without any spaces.
*)
begin
  result:=StringReplace(stIn,' ','',[rfReplaceAll]);
end;

(*
@AI:summary: This function appears to remove any double spaces from the input string, as in {space}{space} is converted to {space}.
@AI:params: stIn: The input string that may contain double spaces which need to be eliminated.
@AI:returns: A string with all double spaces removed.
*)
function NoDoubleSpace(stIn:string):string;
begin
  while Pos(crlf+crlf,stin)<>0 do
    stIn:=StringReplace(stIn,crlf+crlf,crlf,[rfReplaceAll]);
  result:=trim(stIn);
end;

function O2I (obj: TObject): integer;
(*
@AI:summary: Converts an object to an integer representation.
@AI:params: obj: The object to be converted into an integer.
@AI:returns: An integer representing the object. The integer is used to identify primary keys in a SQLite3 table
*)
var
  ptr: Pointer;
begin
  ptr := Pointer(obj);
  Result := integer(ptr);
end;

function I2O (Value: integer): TObject;
(*
@AI:summary: This function likely converts an integer value into an object representation.
@AI:params: Value: The integer input that is to be converted into an object.
@AI:returns: An object that represents the input integer value.  This result is typically used to take a primary key value from a database and assign it to the tObject value in a tStringList.
*)
var
  ptr: Pointer;
begin
  ptr := Pointer(Value);
  Result := TObject(ptr);
end;

function ListObject(lb:TListBox):integer;
(*
@AI:summary: This function uses the o2i function to take the tObject value stored on a tStringList item and returns its integer value.  Defaults to -1 if no item is selected in the listbox as a "safety net".
@AI:params: lb: The list box from which the item count is to be obtained.
@AI:returns: An integer representing the tObject value as an integer.
*)
begin
  result:=-1;
  if lb.ItemIndex<>-1 then begin
    result:=o2i(lb.Items.Objects[lb.ItemIndex]);
  end;
end;

end.

