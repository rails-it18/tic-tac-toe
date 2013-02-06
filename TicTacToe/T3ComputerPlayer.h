//
//  T3ComputerPlayer.h
//  TicTacToe
//
//  Created by Ethan Jud on 2/1/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "T3Game.h"

@interface T3ComputerPlayer : NSObject

// Returns the player that the receiver is playing as,
//  or T3PlayerNone if the receiver is not playing a game.
@property (nonatomic, readonly) T3Player player;

// Starts playing a game. The computer player retains the game object.
// If the computer was playing a previous game, it immediately stops playing
//  the other.
- (void)startPlayingGame:(T3Game *)game asPlayer:(T3Player)player;

// Stops playing a game. The game object is released by the computer player.
- (void)stopPlaying;

@end
