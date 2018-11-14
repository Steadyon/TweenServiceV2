# TweenServiceV2
TweenService V2 efficiently replicates movement between server and client using TweenService
by running the tweens clientside, and then doing a single update server side.

## Module:GetTweenObject(instance [Instance], TweenInfo [TweenInfo Object], PropertyTable [Table]) [Tween]
Parameters are exactly the same as TweenService:Create(), it returns a fake Tween object with Play,
Pause and Stop functions.

## Tween:Play(Yield [Boolean, optional], Player [Player Object, optional])
Runs the tween. The player parameter will only play the tween for that specific player.
The Yield parameter specifies whether the function should yield until the tween has completed or not.

### Tween:Stop(Player [Player Object, optional])
Stops the tween. The player parameter will only stop the tween for that specific player.

### Tween:Pause(Player [Player Object, optional])
Pauses the tween. The player parameter will only pause the tween for that specific player.
