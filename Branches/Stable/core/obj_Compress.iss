/*
	Compression Class

	Interacting with ore in space

BUGS:

*/

objectdef obj_Compress inherits obj_BaseClass
{
	variable int NextRawOreCheckAt = 0
	variable int RawOreCheckIntervalMS = 3000

	method Initialize()
	{
		LogPrefix:Set["${This.ObjectName}"]
		Logger:Log["obj_Compress: Initialized", LOG_MINOR]
		Logger:Log["${LogPrefix}: Initialized", LOG_MINOR]
	}

	function CheckForCompression()
	{
		call This.CompressRawOreIfAvailable
		if !${Return}
		{
			return FALSE
		}

		Logger:Log["Debug: Stacking ore in mining hold after compression"]
		call Ship.StackOreHold
		return TRUE
	}

	function CompressRawOreIfAvailable()
	{
		if ${Script.RunningTime} < ${This.NextRawOreCheckAt}
		{
			return FALSE
		}

		NextRawOreCheckAt:Set[${Script.RunningTime}]
		NextRawOreCheckAt:Inc[${RawOreCheckIntervalMS}]

		call This.MiningHoldHasRawOre
		if !${Return}
		{
			return FALSE
		}

		Logger:Log["Debug: Compressing ore hold via F12 hotkey"]
		press F12
		wait 30
		return TRUE
	}

	function MiningHoldHasRawOre()
	{
		if !${EVEWindow[Inventory].ChildWindow[${MyShip.ID}, ShipGeneralMiningHold](exists)}
		{
			return FALSE
		}

		call Inventory.ShipGeneralMiningHold.Activate
		if !${Inventory.ShipGeneralMiningHold.IsCurrent}
		{
			return FALSE
		}

		variable index:item OreItems
		variable iterator OreIterator

		Inventory.ShipGeneralMiningHold:GetItems[OreItems, "CategoryID == CATEGORYID_ORE"]

		OreItems:GetIterator[OreIterator]
		if ${OreIterator:First(exists)}
		{
			do
			{
				if ${OreIterator.Value.Name.Find["Compressed"]} == 0
				{
					return TRUE
				}
			}
			while ${OreIterator:Next(exists)}
		}

		return FALSE
	}
}
