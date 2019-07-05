// TODO:
//  - Allow player to set objects on top of each other
//  - Move messages to LANGUAGE
//  - Disallow lifting enemies
//  - Flag to let player take inventory items

// Holds an object in front of the player
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


    // Tries to grab object in front of player
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

    // Grabs given object
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

    // Tries to drop object, if nothing is in the way
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

    // Reseases object
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

    // Moves object in front of player, if they intersect
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