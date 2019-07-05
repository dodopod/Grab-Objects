version "4.1.3"

// TODO:
//  - Allow player to set objects on top of each other
//  - Move messages to LANGUAGE

class GrabbyPlayer : DoomPlayer
{
    Default
    {
		//Player.StartItem "Pistol";
		Player.StartItem "NoWeapon";
		Player.StartItem "Clip", 50;
    }
}


class NoWeapon : Fist
{
    Property SlowThreshold : slowThreshold;
    Property LiftThreshold : liftThreshold;

    Default
    {
        Weapon.SlotNumber 1;
        Weapon.AmmoUse2 0;
        NoWeapon.SlowThreshold 100;
        NoWeapon.LiftThreshold 200;

        +Weapon.Alt_Ammo_Optional
        +Weapon.NoAlert
        +Weapon.NoAutoFire
    }

    double slowThreshold;
    double liftThreshold;
    Grabber grabber;

    States
    {
	Ready:
		PUNG A 1 A_WeaponReady();
		Loop;
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


class Grabber : Inventory
{
    Property Offset : ofsX, ofsY, ofsZ; // Offset from player eyes to center of object
    Property Alpha : alpha;             // Alpha of held object
    Property TooHeavyMessage : tooHeavyMessage;
    Property NoRoomMessage : noRoomMessage;


    Default
    {
        Inventory.MaxAmount 1;

        Grabber.Offset 32, 0, 0;
        Grabber.Alpha 0.5;
        Grabber.TooHeavyMessage "It's too heavy to lift.";
        Grabber.NoRoomMessage "You can't drop that here.";
    }


    double ofsX, ofsY, ofsZ;
    Actor holding;
    String TooHeavyMessage;
    String NoRoomMessage;


    override void DoEffect()
    {
        if (!owner || !owner.player || !holding) return;

        Vector3 holdPos = owner.pos;
        Vector3 forward = (Cos(owner.pitch) * Cos(owner.angle), Cos(owner.pitch) * Sin(owner.angle), -Sin(owner.pitch));
        holdPos += forward * ofsX;
        holdPos += AngleToVector(owner.angle - 90, ofsY);
        holdPos.z += owner.player.viewZ - owner.pos.z + ofsZ - holding.height / 2;
        holding.SetOrigin(holdPos, true);
        holding.vel = owner.vel;
    }

    override void DetachFromOwner()
    {
        if (holding) Drop();
        Super.DetachFromOwner();
    }


    bool TryGrab(double range, double maxMass = 0)
    {
        if (!owner || !owner.player) return false;

        FLineTraceData data;
        owner.LineTrace(owner.angle, range, owner.pitch, TRF_AllActors, owner.player.viewZ - owner.pos.z, 0, 0, data);

        if (data.hitType == Trace_HitActor)
        {
            if (maxMass > 0 && data.hitActor.mass > maxMass)
            {
                Console.PrintF(tooHeavyMessage);
                return false;
            }

            Grab(data.hitActor);
            return true;
        }

        return false;
    }

    void Grab(Actor mo)
    {
        if (!mo) return;

        holding = mo;
        holding.bSolid = false;
        holding.bCanPass = false;
        holding.bNoGravity = true;

        int style = holding.GetRenderStyle();
        if (style == Style_Normal) holding.A_SetRenderStyle(alpha, Style_Translucent);
        else holding.alpha = alpha;
    }

    bool TryDrop(double throwSpeed = 0)
    {
        if (!holding) return true;

        holding.bSolid = holding.Default.bSolid;
        holding.bCanPass = holding.Default.bSolid;
        Vector3 realPos = holding.pos;
        MoveOutside(holding, owner, true);
        if (holding.pos.z < holding.GetZAt())
        {
            holding.SetZ(holding.GetZAt());
            MoveOutside(holding, owner, true, true);
        }

        if (holding.CheckBlock()
            || owner.LineTrace( // Make sure we aren't throwing an object through a wall
                owner.angle,
                owner.Distance3d(holding),
                owner.pitch,
                TRF_ThruActors,
                owner.player.viewZ - owner.pos.z)
            || holding.pos.z + holding.height > holding.GetZAt(flags:GZF_Ceiling))
        {
            holding.bSolid = false;
            holding.bCanPass = false;
            holding.SetXyz(realPos);
            Console.Printf(noRoomMessage);
            return false;
        }

        holding.SetXyz(realPos);

        Drop(throwSpeed);
        return true;
    }

    void Drop(double throwSpeed = 0)
    {
        if (!holding) return;

        MoveOutside(holding, owner, false);
        if (holding.pos.z < holding.GetZAt())
        {
            holding.SetZ(holding.GetZAt());
            MoveOutside(holding, owner, false, true);
            throwSpeed = 0; // Set object down, if it would go into the ground
        }

        Vector3 forward = (Cos(owner.pitch) * Cos(owner.angle), Cos(owner.pitch) * Sin(owner.angle), -Sin(owner.pitch));
        holding.vel += throwSpeed * forward;

        holding.alpha = holding.Default.alpha;
        holding.bNoGravity = holding.Default.bNoGravity;
        holding.bSolid = holding.Default.bSolid;
        holding.bCanPass = holding.Default.bCanPass;
        holding = null;
        Destroy();
    }

    void MoveOutside(Actor mo, Actor from, bool test, bool horizontal = false)
    {
        Vector3 forward;
        if (horizontal)
        {
            forward.xy = AngleToVector(from.angle);
        }
        else
        {
            forward = (Cos(from.pitch) * Cos(from.angle), Cos(from.pitch) * Sin(from.angle), -Sin(from.pitch));
        }

        Vector3 newPos = mo.pos;
        while (Abs(newPos.x - from.pos.x) <= mo.radius + from.radius
            && Abs(newPos.y - from.pos.y) <= mo.radius + from.radius
            && newPos.z - from.pos.z <= from.height * from.player.crouchFactor
            && newPos.z - from.pos.z >= -mo.height)
        {
            newPos += forward;
        }

        if (test) mo.SetXyz(newPos);
        else mo.SetOrigin(newPos, true);
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