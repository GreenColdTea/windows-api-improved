package winapi.gdi;

import winapi.gdi.WindowsGDI.WindowsGDIEffect;

/*
 * This is a simple class that contains data from the GDI effect before it is started
 * 
 * Author: Slushi
 */
class WindowsGDIEffectData
{
	public var gdiEffect:WindowsGDIEffect;
	public var wait:Float = 0;
	public var enabled:Bool = false;

	public function new(_gdiEffect:WindowsGDIEffect, _wait:Float = 0, _enabled:Bool = false)
	{
		this.gdiEffect = _gdiEffect;
		this.wait = _wait;
		this.enabled = _enabled;
	}
}
