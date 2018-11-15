# TweenServiceV2
TweenService V2 efficiently replicates movement between server and client using TweenService
by running the tweens clientside, and then doing a single update server side.

## Module:GetTweenObject(instance [Instance], TweenInfo [TweenInfo Object], PropertyTable [Table]) [Tween]
Parameters are exactly the same as TweenService:Create(), it returns a fake Tween object with Play,
Pause and Stop functions.

### Tween:QueuePlay(Yield [Boolean, optional], Player [Player Object, optional])

Add the tween to a tween queue which will start playing the queue automatically immediately after the previous tween on that instance completes. Behaves exactly the same way as Tween:Play() once started, except the initial firing of the tween is managed on the client. For this reason, best practice is to fire this event as close to when you would like it to be played on the client to maintain alignment between tweens. If fired multiple times in a short time frame, this may result in clients becoming out of sync over time.

## Tween:Play(Yield [Boolean, optional], Player [Player Object, optional])
Runs the tween. The player parameter will only play the tween for that specific player.
The Yield parameter specifies whether the function should yield until the tween has completed or not.

### Tween:Stop(Player [Player Object, optional])
Stops the tween. The player parameter will only stop the tween for that specific player.

### Tween:Pause(Player [Player Object, optional])
Pauses the tween. The player parameter will only pause the tween for that specific player.
