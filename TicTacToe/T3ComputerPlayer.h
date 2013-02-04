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

- (void)startPlayingGame:(T3Game *)game asPlayer:(T3Player)player;
- (void)stopPlaying;

@end
