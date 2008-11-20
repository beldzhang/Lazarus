{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

-------------------------------------------------------------------------------}
unit SynEditMarkupBracket;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditMarkup, SynEditMiscClasses, Controls, LCLProc;

type
  { TSynEditMarkupBracket }

  TSynEditMarkupBracket = class(TSynEditMarkup)
  private
    // Physical Position
    FBracketHighlightPos: TPoint;
    FBracketHighlightAntiPos: TPoint;
  protected
    procedure FindMatchingBracketPair(PhysCaret: TPoint;
      var StartBracket, EndBracket: TPoint);
  public
    constructor Create(ASynEdit: TCustomControl);

    function GetMarkupAttributeAtRowCol(const aRow, aCol: Integer): TSynSelectedColor; override;
    function GetNextMarkupColAfterRowCol(const aRow, aCol: Integer): Integer; override;

    procedure InvalidateBracketHighlight;
  end;

implementation
uses
  SynEdit;

{ TSynEditMarkupBracket }

constructor TSynEditMarkupBracket.Create(ASynEdit : TCustomControl);
begin
  inherited Create(ASynEdit);
  FBracketHighlightPos.Y := -1;
  FBracketHighlightAntiPos.Y := -1;
  MarkupInfo.Foreground := clNone;
  MarkupInfo.Background := clNone;
  MarkupInfo.Style := [fsBold];
  MarkupInfo.StyleMask := [];
end;

procedure TSynEditMarkupBracket.FindMatchingBracketPair(PhysCaret : TPoint;
  var StartBracket, EndBracket : TPoint);
var
  StartLine: string;
  LogCaretXY: TPoint;
  x: Integer;
begin
  StartBracket.Y:=-1;
  EndBracket.Y:=-1;
  if (PhysCaret.Y<1) or (PhysCaret.Y>Lines.Count) or (PhysCaret.X<1) then exit;
  StartLine := Lines[PhysCaret.Y - 1];

  // check for bracket, before cursor
  if PhysCaret.x > 1 then begin
    // need to dec PhysCaret, in case we are in the middle of a tab
    dec(PhysCaret.x);
    LogCaretXY:=TSynEdit(SynEdit).PhysicalToLogicalPos(PhysCaret);
    x := LogCaretXY.x;
    if (x <= length(StartLine))
    and (StartLine[x] in ['(',')','{','}','[',']']) then begin
      StartBracket:=PhysCaret;
      EndBracket:=TSynEdit(SynEdit).FindMatchingBracket(PhysCaret,false,false,false,false);
      exit;
    end;
    // check for bracket after caret
    inc(PhysCaret.x);;
  end;

  LogCaretXY:=TSynEdit(SynEdit).PhysicalToLogicalPos(PhysCaret);
  x := LogCaretXY.x;
  if (length(StartLine) < x)
  or (not (StartLine[x] in ['(',')','{','}','[',']'])) then exit;

  StartBracket:=PhysCaret;
  EndBracket:=TSynEdit(SynEdit).FindMatchingBracket(PhysCaret,false,false,false,false);
end;

procedure TSynEditMarkupBracket.InvalidateBracketHighlight;
var
  NewPos, NewAntiPos, SwapPos : TPoint;
begin
  NewPos.Y:=-1;
  NewAntiPos.Y:=-1;
  if eoBracketHighlight in TSynEdit(SynEdit).Options 
  then FindMatchingBracketPair(TSynEdit(SynEdit).CaretXY, NewPos, NewAntiPos);

  // Always keep ordered
  if (NewAntiPos.Y > 0)
  and ((NewAntiPos.Y < NewPos.Y) or ((NewAntiPos.Y = NewPos.Y) and (NewAntiPos.X < NewPos.X)))
  then begin
    SwapPos    := NewAntiPos;
    NewAntiPos := NewPos;
    NewPos     := SwapPos;
  end;

  // invalidate old bracket highlighting, if changed
  if (FBracketHighlightPos.Y > 0)
  and ((FBracketHighlightPos.Y <> NewPos.Y) or (FBracketHighlightPos.X <> NewPos.X))
  then begin
    //DebugLn('TCustomSynEdit.InvalidateBracketHighlight A Y=',dbgs(FBracketHighlightPos));
    InvalidateSynLines(FBracketHighlightPos.Y,FBracketHighlightPos.Y);
  end;

  if (FBracketHighlightAntiPos.Y > 0)
  and (FBracketHighlightPos.Y <> FBracketHighlightAntiPos.Y)
  and ((FBracketHighlightAntiPos.Y <> NewAntiPos.Y) or (FBracketHighlightAntiPos.X <> NewAntiPos.X))
  then
    InvalidateSynLines(FBracketHighlightAntiPos.Y,FBracketHighlightAntiPos.Y);

  // invalidate new bracket highlighting, if changed
  if NewPos.Y>0 then begin
    //DebugLn('TCustomSynEdit.InvalidateBracketHighlight C Y=',dbgs(NewPos.Y),' X=',dbgs(NewPos.X),' Y=',dbgs(NewAntiPos.Y),' X=',dbgs(NewAntiPos.X));
    if ((FBracketHighlightPos.Y <> NewPos.Y) or (FBracketHighlightPos.X <> NewPos.X))
    then InvalidateSynLines(NewPos.Y, NewPos.Y);

    if ((NewPos.Y <> NewAntiPos.Y)
        or ((FBracketHighlightPos.Y = NewPos.Y) and (FBracketHighlightPos.X = NewPos.X))
       )
    and ((FBracketHighlightAntiPos.Y <> NewAntiPos.Y) or (FBracketHighlightAntiPos.X <> NewAntiPos.X))
    then InvalidateSynLines(NewAntiPos.Y, NewAntiPos.Y);
  end;
  FBracketHighlightPos     := NewPos;
  FBracketHighlightAntiPos := NewAntiPos;
//  DebugLn('TCustomSynEdit.InvalidateBracketHighlight C P=',dbgs(NewPos),' A=',dbgs(NewAntiPos), ' LP=',dbgs(fLogicalPos),' LA',dbgs(fLogicalAntiPos));
end;

function TSynEditMarkupBracket.GetMarkupAttributeAtRowCol(const aRow, aCol: Integer) : TSynSelectedColor;
begin
  Result := nil;
  if ((FBracketHighlightPos.y = aRow) and  (FBracketHighlightPos.x = aCol))
  or ((FBracketHighlightAntiPos.y = aRow) and  (FBracketHighlightAntiPos.x = aCol))
  then Result := MarkupInfo;
end;

function TSynEditMarkupBracket.GetNextMarkupColAfterRowCol(const aRow, aCol: Integer) : Integer;
begin
  Result := -1;
  if (FBracketHighlightPos.y = aRow) then begin
    if  (FBracketHighlightPos.x > aCol)
    then Result := FBracketHighlightPos.x
    else if  (FBracketHighlightPos.x + 1 > aCol)
    then Result := FBracketHighlightPos.x + 1; // end of bracket
  end;
  if (FBracketHighlightAntiPos.y = aRow) then begin
    if  (FBracketHighlightAntiPos.x > aCol)
    and ((FBracketHighlightAntiPos.x < Result) or (Result < 0))
    then Result := FBracketHighlightAntiPos.x
    else if  (FBracketHighlightAntiPos.x + 1 > aCol)
    and ((FBracketHighlightAntiPos.x + 1 < Result) or (Result < 0))
    then Result := FBracketHighlightAntiPos.x + 1;
  end
end;

end.

