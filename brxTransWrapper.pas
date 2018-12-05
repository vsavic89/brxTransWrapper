//********************************************************************************************************
//********************************************************************************************************
// Component name: brxTransWrapper
// Usage: Delphi XE3+ (with FireDAC library) (although, it can be used also with AnyDac in older versions of Delphi, with some changes)
// Author: Vladimir Saviæ
// Version: 1.0.0.0
// Version Date: 4.12.2018
//********************************************************************************************************
//********************************************************************************************************
unit brxTransWrapper;

interface

uses
  System.SysUtils, System.Classes,
   FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS,
  FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async, FireDAC.DApt,
  Data.DB, FireDAC.Comp.DataSet, FireDAC.Comp.Client,System.Variants;

type
  TStringArray=array of string;

type
  TbrxTransWrapper = class(TComponent)
  private
    { Private declarations }
    FConnection:TFDConnection;
    FTransaction:TFDTransaction;
    FQuery:TFDQuery;
    FMemTable:TFDMemTable;
    FSToredProc:TFDStoredProc;
    FStringArray:TStringArray;
    procedure SetConnection(const Value: TFDConnection);
    procedure SetTransaction(const Value: TFDTransaction);
    procedure SetStoredProc(const Value: TFDStoredProc);
    procedure SetQuery(const Value: TFDQuery);
    procedure SetMemTable(const Value: TFDMemTable);
    procedure GetParameters(ASQL:string);
  protected
    { Protected declarations }
  public
    { Public declarations }
  published
    { Published declarations }
    procedure OpenQuery(ASQL: string;const AParamValues:array of Variant);
    procedure OpenStoredProc(AProcedureName: string;const AParamNames: array of string; const AParamValues: array of variant); //not tested!
    procedure ExecStoredProc(AProcedureName: string;const AParamNames:array of string;const AParamValues:array of variant);
    procedure ExecQuery(ASQL: string;const AParamValues:array of Variant);
    property Connection: TFDConnection read FConnection write SetConnection;
    property Transaction:TFDTransaction   read  FTransaction write SetTransaction;
    property StoredProc: TFDStoredProc read FSToredProc write SetStoredProc;
    property Query: TFDQuery read FQuery write SetQuery;
    property MemTable: TFDMemTable read FMemTable write SetMemTable;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('BRXComponents', [TbrxTransWrapper]);
end;

{ TbrxTransWrapper }

procedure TbrxTransWrapper.GetParameters(ASQL:string);
var
  s:string;
  intTwoDots,intComma,intSpace,intClosedBracket:integer;   //":",","," ",")"
  strParam,strPom:string;
  blnUseComma,blnUseSpace,blnUseClosedBracket:boolean; //"use comma","use space","use end brace (')')"
begin
  SetLength(FStringArray,0);
  s:=ASQL;
  repeat
    blnUseSpace:=false;
    blnUseComma:=false;
    blnUseClosedBracket:=false;
    intTwoDots:=pos(':',s);
    if intTwoDots>0 then
    begin
      strPom:=copy(s,intTwoDots+1,Length(s));
      intComma:=pos(',',strPom);
      intSpace:=pos(' ',strPom);
      intClosedBracket:=pos(')',strPom);
      if intComma>0 then
      begin
        if intSpace>0 then
        begin
          if intClosedBracket>0 then
          begin
            if intSpace>intClosedBracket then
            begin
              if intClosedBracket>intComma then
              begin
                blnUseComma:=true;
              end else begin
                blnUseClosedBracket:=true;
              end;
            end else begin
              if intSpace>intComma then
                 blnUseComma:=true
              else
                 blnUseSpace:=true;
            end;
          end else begin
            if intSpace>intComma then
            begin
               blnUseComma:=true;
            end
            else
            begin
               blnUseSpace:=true;
            end;
          end;
        end else begin
          if intClosedBracket>0 then
          begin
            if intClosedBracket>intComma then
               blnUseComma:=true
            else
                blnUseClosedBracket:=true;
          end else begin
             blnUseComma:=true;
          end
        end;
      end else if(intSpace>0) then //no comma...
      begin
        if(intClosedBracket>0) then
        begin
          if(intSpace>intClosedBracket) then
          begin
            blnUseClosedBracket:=true;
          end else
          begin
             blnUseSpace:=true;
          end;
        end else begin
           blnUseSpace:=true;
        end;
      end else if(intClosedBracket>0) then begin
          blnUseClosedBracket:=true;
      end else begin
        strParam:=Copy(strPom,1,length(strPom));
      end;
      if blnUseComma then
          strParam:=Copy(strPom,1,intComma-1)
      else if blnUseSpace then
          strParam:=Copy(strPom,1,intSpace-1)
      else if blnUseClosedBracket then
          strParam:=Copy(strPom,1,intClosedBracket-1);
      s:=Copy(s,intTwoDots+1,Length(s));
      SetLength(FStringArray,length(FStringArray)+1);
      FStringArray[Length(FStringArray)-1]:=strParam;
    end;
  until intTwoDots=0;
end;

procedure TbrxTransWrapper.ExecQuery(ASQL: string;
  const AParamValues: array of Variant);
var i:integer;
begin
    GetParameters(asql);
    FTransaction.StartTransaction;
    try
      with FQuery do
      begin
        close;
        sql.Clear;
        sql.Add(ASQL);
        for i := low(FStringArray) to High(FStringArray) do
        begin
          ParamByName(FStringArray[i]).Value:=AParamValues[i];
        end;
        execsql();
      end;
      FTransaction.Commit;
    except
      FTransaction.Rollback;
      raise;
    end;
    FQuery.Active:=false;
end;

procedure TbrxTransWrapper.ExecStoredProc(AProcedureName: string;
  const AParamNames: array of string; const AParamValues: array of variant);
var i:integer;
begin
    FTransaction.StartTransaction;
    try
      with FStoredProc do
      begin
        close;
        params.Clear;
        Params.ClearValues();
        StoredProcName:=AProcedureName;
        prepare;
        for i := low(AParamNames) to High(AParamNames) do
        begin
          ParamByName(aparamnames[i]).Value:=AParamValues[i];
        end;
        ExecProc;
      end;
      FTransaction.Commit;
    except
      FTransaction.Rollback;
      raise;
    end;
    FSToredProc.Active:=false;
end;

procedure TbrxTransWrapper.OpenQuery(ASQL: string;
  const AParamValues: array of Variant);
var i:integer;
begin
    GetParameters(asql);
    FTransaction.StartTransaction;
    try
      with FQuery do
      begin
        close;
        sql.Clear;
        sql.Add(ASQL);
        for i := low(FStringArray) to High(FStringArray) do
        begin
          ParamByName(FStringArray[i]).Value:=AParamValues[i];
        end;
        Open();
        FetchAll;
        First;
      end;
      FMemTable.Active:=false;
      FMemTable.AppendData(FQuery);
      FMemTable.Active:=true;
      FMemTable.FetchAll;
      FMemTable.First;
      FTransaction.Commit;
    except
      FTransaction.Rollback;
      raise;
    end;
    FQuery.Active:=false;
end;

procedure TbrxTransWrapper.OpenStoredProc(AProcedureName: string;
  const AParamNames: array of string; const AParamValues: array of variant);
var i:integer;
begin
    FTransaction.StartTransaction;
    try
      with FSToredProc do
      begin
        close;
        params.Clear;
        Params.ClearValues();
        StoredProcName:=AProcedureName;
        prepare;
        for i := low(AParamNames) to High(AParamNames) do
        begin
          ParamByName(aparamnames[i]).Value:=AParamValues[i];
        end;
        Open();
        FetchAll;
        First;
      end;
      FMemTable.Active:=false;
      FMemTable.AppendData(FSToredProc);
      FMemTable.Active:=true;
      FMemTable.FetchAll;
      FMemTable.First;
      FTransaction.Commit;
    except
      FTransaction.Rollback;
      raise;
    end;
    FSToredProc.Active:=false;
end;

procedure TbrxTransWrapper.SetConnection(const Value: TFDConnection);
begin
  FConnection := value;
end;

procedure TbrxTransWrapper.SetMemTable(const Value: TFDMemTable);
begin
  FMemTable := Value;
end;

procedure TbrxTransWrapper.SetQuery(const Value: TFDQuery);
begin
  FQuery := Value;
end;

procedure TbrxTransWrapper.SetStoredProc(const Value: TFDStoredProc);
begin
  FSToredProc := Value;
end;

procedure TbrxTransWrapper.SetTransaction(const Value: TFDTransaction);
begin
  FTransaction := Value;
end;

end.
