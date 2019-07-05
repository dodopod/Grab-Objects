version "4.1.3"

#include "zscript/grab_objects/grabber.zs"

class GrabbyPlayer : DoomPlayer
{
    Default
    {
		//Player.StartItem "Pistol";
		Player.StartItem "GrabbyFist";
		Player.StartItem "Clip", 50;
    }
}


class GrabbyFist : Fist
{
    Property SlowThreshold : slowThreshold;
    Property LiftThreshold : liftThreshold;

    Default
    {
        Weapon.SlotNumber 1;
        GrabbyFist.SlowThreshold 100;
        GrabbyFist.LiftThreshold 200;

        +Weapon.NoAlert
        +Weapon.NoAutoFire
    }

    double slowThreshold;
    double liftThreshold;
    Grabber grabber;

    States
    {
    Ready.Holding:
        PUNG A 1 A_WeaponReady(WRF_NoPrimary);
        Loop;
    AltFire:
        PUNG A 1
        {
            if (CountInv("Grabber")) return ResolveState("AltFire.Drop");
            return ResolveState("AltFire.Grab");
        }
    AltFire.Grab:
        PUNG A 1
        {
            invoker.grabber = Grabber(Spawn("Grabber"));
            AddInventory(invoker.grabber);
            if (invoker.grabber.TryGrab(64, invoker.liftThreshold))
            {
                if (invoker.grabber.holding.mass >= invoker.slowThreshold) A_GiveInventory("PowerEncumbrance");
                return ResolveState("Ready.Holding");
            }

            invoker.grabber.Destroy();
            return ResolveState("Ready");
        }
    AltFire.Drop:
        PUNG A 1
        {
            double throwSpeed = Max(16 - 0.12 * invoker.grabber.holding.mass, 0);
            if (invoker.grabber.TryDrop(throwSpeed))
            {
                A_TakeInventory("PowerEncumbrance");
                return ResolveState("Ready");
            }

            return ResolveState("Ready.Holding");
        }
    }
}


class PowerEncumbrance : PowerSpeed
{
    Default
    {
        Speed 0.25;
    }
}


class MyExplosiveBarrel : ExplosiveBarrel replaces ExplosiveBarrel
{
    Default
    {
        Mass 100;
        +CanPass
    }
}

class MyCandleStick : Candlestick replaces Candlestick
{
    Default
    {
        Mass 1;
        +CanPass
        +Shootable
        +NoBlood
    }
}

class MyTechPillar : TechPillar replaces TechPillar
{
    Default
    {
        Mass 400;
    }
}