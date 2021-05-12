unit PowerTools;

interface

uses
  Sigma.Document,
  System.UI.Ribbon,
  System.UI.Dialogs,
  System.UI.Layout,
  System.UI.Progress,
  System.Localization,
  CostPerArea;

type

TSortDirection = (sortAsc, sortDesc);

TRemoveUI = class(TDialog)
  private
    FDeleteQty, FDeleteUP, FDeleteDisabled: TCheckBox;
  public
    DeleteQty, DeleteUP, DeleteDisabled = false;
    constructor Create;
    function Execute(): Boolean;
    destructor Destroy; override;
end;

TSigmaPowerTools = class
  private
      sortField: TSigmaField;
      sortDirection: TSortDirection;
      FRibbonTab: TRibbonTab;
      FRibbonGroup: TRibbonTabGroup;
      procedure AddRibbon;
      procedure Sort(field: TSigmaField; sort: TSortDirection);
      function ItemSort( a, b: TSigmaItem): integer;
      function ItemSortNumber( a, b: TSigmaItem): integer;
      procedure SortTextA(a: tribbonitem);
      procedure SortTextD(a: tribbonitem);
      procedure SortNumberA(a: tribbonitem);
      procedure SortNumberD(a: tribbonitem);
      procedure SortUPA(a: tribbonitem);
      procedure SortUPD(a: tribbonitem);
      procedure SortRegCostA(a: tribbonitem);
      procedure SortRegCostD(a: tribbonitem);

      procedure RemoveComponents(a: TRibbonItem);

      procedure RemoveZero(qty, cost, disabled: boolean);
  public
      constructor Create;
      destructor Destroy; override;
end;

implementation


constructor TRemoveUI.Create;
begin
  inherited Create;
  Width := 500;
  Height := 300;
  Caption := _("Delete Components");
  Title := _("Choose which components to delete");

  var Layout := TLayout.Create(Self);
  Layout.Parent := Container;
  Layout.ParentBackground := true;
  Layout.Align := alClient;

  FDeleteQty := TCheckBox.Create(self);
  FDeleteQty.Checked := DeleteQty;
  var Itm := Layout.Items.CreateItem(FDeleteQty);
  Itm.Caption.Text := _("Components having quantity zero");

  FDeleteUP := TCheckBox.Create(self);
  FDeleteUP.Checked := DeleteUP;
  Itm := Layout.Items.CreateItem(FDeleteUP);
  Itm.Caption.Text := _("Components having unit price zero");

  FDeleteDisabled := TCheckBox.Create(self);
  FDeleteDisabled.Checked := DeleteDisabled;
  Itm := Layout.Items.CreateItem(FDeleteDisabled);
  Itm.Caption.Text := _("Components that are disabled");

  Self.ActionOK.Caption := _("Delete");

end;

function TRemoveUI.Execute(): Boolean;
begin
  result := inherited Execute;
  DeleteQty :=  FDeleteQty.Checked;
  DeleteUP := FDeleteUP.Checked;
  DeleteDisabled := FDeleteDisabled.Checked;
end;

destructor TRemoveUI.Destroy;
begin
  FDeleteQty.Free;
  FDeleteUP.Free;
  FDeleteDisabled.Free;
  inherited;
end;

constructor TSigmaPowerTools.Create;
begin
    AddRibbon();
    var cpa := TCostPrArea.Create(FRibbonGroup); // create instance to add CostPrArea functionality
end;

destructor TSigmaPowerTools.Destroy;
begin
    FRibbonGroup.Free;
end;

procedure TSigmaPowerTools.AddRibbon;
begin
  FRibbonTab := Ribbon.Tabs.FindTab("RibbonMainTabTools", false);
  if FRibbonTab = nil then
     exit;

  FRibbonGroup := FRibbonTab.Groups.Add;
  FRibbonGroup.Caption := 'Sigma Power Tools';


  var Item := FRibbonGroup.Items.Add(TRibbonLargeButtonItem) as TRibbonLargeButtonItem;
  Item.ButtonStyle := rbsDropDown;
  Item.LargeGlyph.LoadFromFile('icons\sortaz.png', true);
  var Action = Application.Actions.Add;
  Action.Caption := _('Sort current page');
  Item.Action := Action;
  Action.OnUpdate := procedure(A: TAction) begin
       A.Enabled := Application.ActiveProject <> nil;
  end;


  var subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Text, ascending');
  subItem.OnClick := SortTextA;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Text, descending');
  subItem.OnClick := SortTextD;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Number, ascending');
  subItem.OnClick := SortNumberA;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Number, descending');
  subItem.OnClick := SortNumberD;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Unit price, ascending');
  subItem.OnClick := SortUPA;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Unit price, descending');
  subItem.OnClick := SortUPD;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Regulated cost price, ascending');
  subItem.OnClick := SortRegCostA;

  subItem := Item.DropDownMenu.Items.Add(TRibbonButtonItem);
  subItem.Caption := _('Sort by Regulated cost price, descending');
  subItem.OnClick := SortRegCostD;

  Item := FRibbonGroup.Items.Add(TRibbonLargeButtonItem) as TRibbonLargeButtonItem;

  Action := Application.Actions.Add;
  Action.Caption := _('Batch Delete Components');
  Item.Action := Action;
  Item.OnClick := RemoveComponents;
  Item.LargeGlyph.LoadFromFile('icons\delete.png', true);
  Action.OnUpdate := procedure(A: TAction) begin
       A.Enabled := Application.ActiveProject <> nil;
  end;

end;

procedure TSigmaPowerTools.RemoveComponents(a: TRibbonItem);
begin
  var Dlg := TRemoveUI.Create;
  if (Dlg.Execute) then
    RemoveZero(Dlg.DeleteQty, Dlg.DeleteUP, Dlg.DeleteDisabled);
end;

procedure TSigmaPowerTools.RemoveZero(qty, cost, disabled: boolean);
var queue: array of TSigmaItem;
begin
    Application.ActiveProject.BeginUpdate;
    var Progress := ShowProgress( _("Deleting components") );
    Progress.Marquee := true;
    try
        queue.Insert(0, Application.ActiveProject.RootItem);

        while queue.Length > 0 do
        begin
            var itm := queue.pop;
            var itmCount = 0;

            while itmCount < itm.Items.Count do
            begin
                var itmqty = itm.Items[itmCount].Values[tcQuantity] = 0;
                var itmcost = itm.Items[itmCount].Values[tcUnitPrice] = 0;
                var itmdisabled = not itm.Items[itmCount].Enabled;

                if (qty and itmqty) or (cost and itmcost) or (disabled and itmdisabled)then
                    Application.ActiveProject.DeleteItem(itm.Items[itmCount])
                else begin
                    queue.Insert(0, itm.Items[itmCount]);
                    inc(itmCount);
                end;
            end;

        end;
    finally
        Application.ActiveProject.EndUpdate;
        Application.ActiveProject.Update;
        Progress.Free;
    end;

end;



function TSigmaPowerTools.ItemSort( a, b: TSigmaItem): integer;
begin
  if sortDirection = sortAsc then
    result := CompareStr(a.Values[sortField], b.Values[sortField])
  else
    result := CompareStr(b.Values[sortField], a.Values[sortField])
end;

function TSigmaPowerTools.ItemSortNumber( a, b: TSigmaItem): integer;
begin
  if ( a.Values[sortField] = b.Values[sortField] ) then
    result := 0
  else if (a.Values[sortField] > b.Values[sortField]) then
    result := 1
  else
    result := -1;

  if sortDirection = sortDesc then
    result := -result;
end;

procedure TSigmaPowerTools.SortTextA(a: tribbonitem);
begin
    Sort(tcText, sortAsc);
end;

procedure TSigmaPowerTools.SortTextD(a: tribbonitem);
begin
    Sort(tcText, sortDesc);
end;

procedure TSigmaPowerTools.SortNumberA(a: tribbonitem);
begin
    Sort(tcNumber, sortAsc);
end;

procedure TSigmaPowerTools.SortNumberD(a: tribbonitem);
begin
    Sort(tcNumber, sortDesc);
end;

procedure TSigmaPowerTools.SortUPA(a: tribbonitem);
begin
    Sort(tcUnitprice, sortAsc);
end;

procedure TSigmaPowerTools.SortUPD(a: tribbonitem);
begin
    Sort(tcUnitPRice, sortDesc);
end;

procedure TSigmaPowerTools.SortRegCostA(a: tribbonitem);
begin
    Sort(tcRegCostPrice, sortAsc);
end;

procedure TSigmaPowerTools.SortRegCostD(a: tribbonitem);
begin
    Sort(tcRegCostPrice, sortDesc);
end;



procedure TSigmaPowerTools.Sort(field: TSigmaField; sort: TSortDirection);
var
  SL: array of TSigmaItem;
begin
  sortField := field;
  sortDirection := sort;
  var P := Application.ActiveProject;
  P.BeginUpdate;
  P.BeginUndoBlock('Sort page');
  try
    SL.Clear;
    for var i := 0 to P.SelectedItem.Items.Count-1 do
      SL.Add(P.SelectedItem.Items[i]);

    if ( field in [tcNumber, tcText]) then
        SL.Sort(ItemSort)
    else
        SL.Sort(ItemSortNumber);

    for var i := 0 to SL.Count-1 do
      SL[i].MoveTo(P.SelectedItem);
  finally
    P.EndUndoBlock;
    P.EndUpdate;
    P.Update;
  end;
end;


initialization
//  Localizer.AddMissingTranslations := True;
  var Sort := TSigmaPowerTools.Create;
//  Localizer.Save;
//  Localizer.Strings.SaveToFile("c:\tmp\ggg.txt");
finalization
  Sort.Free;


