(*
@AI:unit-summary: This Pascal unit provides utility functions for string manipulation, object-integer conversions, and form resizing, primarily aimed at enhancing user interface elements and managing object references in a list box context.
*)
unit MiscFunctions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls, Forms, LCLIntf, LCLType, Controls, Math, Imaging, ImagingTypes;

function NoSpaces (stIn: string): string;
function NoDoubleSpace (stIn: string): string;
function O2I (obj: TObject): integer;
function I2O (Value: integer): TObject;
function ListObject (lb: TListBox): integer;
procedure SizeForm (frm, relativeTo: TForm; Scale: byte);
function SafeComponentName (Raw: string): string;
function CalcCRC32Hex (Stream: TStream): string;
procedure ResizeImageMax (var Img: TImageData; MaxWidth, MaxHeight: integer);

implementation

const
  CRLF = chr(13) + chr(10);

procedure ResizeImageMax (var Img: TImageData; MaxWidth, MaxHeight: integer);
var
  Scale: single;
  NewWidth, NewHeight: integer;
begin
  if (Img.Width <= MaxWidth) and (Img.Height <= MaxHeight) then begin
    Exit;
  end;

  Scale := Min(MaxWidth / Img.Width, MaxHeight / Img.Height);
  NewWidth := Round(Img.Width * Scale);
  NewHeight := Round(Img.Height * Scale);

  ResizeImage(Img, NewWidth, NewHeight, rfLanczos);
end;


function CalcCRC32Hex (Stream: TStream): string;
const
  CRC32_POLY = $EDB88320;
var
  Table: array[0..255] of longword;
  CRC: longword;
  I, J: integer;
  Buf: array[0..4095] of byte;
  Count: integer;
begin
  // Generate table once (static cache optional)
  for I := 0 to 255 do begin
    CRC := I;
    for J := 0 to 7 do begin
      if (CRC and 1) <> 0 then begin
        CRC := (CRC shr 1) xor CRC32_POLY;
      end else begin
        CRC := CRC shr 1;
      end;
    end;
    Table[I] := CRC;
  end;

  CRC := $FFFFFFFF;
  Stream.Position := 0;
  repeat
    Count := Stream.Read(Buf, SizeOf(Buf));
    for I := 0 to Count - 1 do begin
      CRC := (CRC shr 8) xor Table[(CRC xor Buf[I]) and $FF];
    end;
  until Count = 0;
  CRC := CRC xor $FFFFFFFF;

  Result := IntToHex(CRC, 8);
end;

procedure SizeForm (frm, relativeTo: TForm; Scale: byte);
(*
@AI:summary: Adjusts the size of a form based on a specified scaling factor relative to another form.
@AI:params: frm: The form whose size will be adjusted.
@AI:params: relativeTo: The form that serves as the reference for scaling.
@AI:params: Scale: The scaling factor to apply to the size of the form.
@AI:returns:
*)
var
  TargetMonitor: TMonitor;
  ScaledWidth, ScaledHeight: integer;
begin
  // Clamp Scale between 50% and 100%
  Scale := Min(100, Max(50, Scale));

  if Assigned(relativeTo) then begin
    TargetMonitor := Screen.MonitorFromWindow(HWND(relativeTo.Handle));
  end else begin
    TargetMonitor := Screen.Monitors[0];
  end;

  ScaledWidth := (TargetMonitor.Width * Scale) div 100;
  ScaledHeight := (TargetMonitor.Height * Scale) div 100;

  frm.Width := ScaledWidth;
  frm.Height := ScaledHeight;
  frm.Left := TargetMonitor.Left + ((TargetMonitor.Width - frm.Width) div 2);
  frm.Top := TargetMonitor.Top + ((TargetMonitor.Height - frm.Height) div 2);
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
  Cleaned := '';
  for i := 1 to Length(Raw) do begin
    if Raw[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then begin
      Cleaned := Cleaned + Raw[i];
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

function NoSpaces (stIn: string): string;
(*
@AI:summary: This function removes all spaces from the input string.
@AI:params: stIn: The input string from which spaces will be removed.
@AI:returns: A string that contains the input string without any spaces.
*)
begin
  Result := StringReplace(stIn, ' ', '', [rfReplaceAll]);
end;

(*
@AI:summary: This function appears to remove any double spaces from the input string, as in {space}{space} is converted to {space}.
@AI:params: stIn: The input string that may contain double spaces which need to be eliminated.
@AI:returns: A string with all double spaces removed.
*)
function NoDoubleSpace (stIn: string): string;
begin
  while Pos(crlf + crlf, stin) <> 0 do begin
    stIn := StringReplace(stIn, crlf + crlf, crlf, [rfReplaceAll]);
  end;
  Result := trim(stIn);
end;

(*
@AI:action O2I: Converts a TObject pointer into an integer. Used to store object references (e.g., ListBox/ComboBox items) as Integer keys.
@AI:params: obj: The object whose memory address will be cast to an integer.
@AI:returns: Integer representation of the object's pointer.
*)
function O2I (obj: TObject): integer;
var
  ptr: Pointer;
begin
  ptr := Pointer(obj);
  Result := integer(ptr);
end;

{*
@AI:action I2O: Converts an integer (originally created from a TObject) back into a TObject pointer.
@AI:params: id: An integer representing a stored object pointer.
@AI:returns: The original TObject corresponding to that integer.
*}
function I2O (Value: integer): TObject;
var
  ptr: Pointer;
begin
  ptr := Pointer(Value);
  Result := TObject(ptr);
end;

function ListObject (lb: TListBox): integer;
(*
@AI:summary: This function uses the o2i function to take the tObject value stored on a tStringList item and returns its integer value.  Defaults to -1 if no item is selected in the listbox as a "safety net".
@AI:params: lb: The list box from which the item count is to be obtained.
@AI:returns: An integer representing the tObject value as an integer.
*)
begin
  Result := -1;
  if lb.ItemIndex <> -1 then begin
    Result := o2i(lb.Items.Objects[lb.ItemIndex]);
  end;
end;

end.
