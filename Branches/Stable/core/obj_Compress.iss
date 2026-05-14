/*
	Compression Class

	Interacting with ore in space

BUGS:

*/

objectdef obj_Compress inherits obj_BaseClass
{
	method Initialize()
	{
		LogPrefix:Set["${This.ObjectName}"]
		Logger:Log["obj_Compress: Initialized", LOG_MINOR]
		Logger:Log["${LogPrefix}: Initialized", LOG_MINOR]
	}

	function CheckForCompression()
	{
		Logger:Log["Debug: Compressing ore hold via F12 hotkey"]
		press F12
		wait 30
		Logger:Log["Debug: Stacking ore in mining hold after compression"]
		call Ship.StackOreHold
	}
}
