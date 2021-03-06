//
//  T3Game.h
//  TicTacToe
//
//  Created by Ethan Jud on 1/30/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import <Foundation/Foundation.h>

// Possible players that can occupy a square.
typedef enum {
    T3PlayerNone,
    T3PlayerX,
    T3PlayerO
} T3Player;

// Posted when a turn was taken in the game.
//  userInfo contains T3TurnPlayerKey, T3TurnRowKey, and T3TurnColKey,
//  all unsigned integer values.
extern NSString *const T3TurnTakenInGameNotification;
extern NSString *const T3TurnPlayerKey;
extern NSString *const T3TurnRowKey;
extern NSString *const T3TurnColKey;

@interface T3Game : NSObject

// The player whose turn it is, or T3PlayerNone if the game is over.
@property (nonatomic, readonly) T3Player currentPlayer;

// Whether the game is over
@property (nonatomic, readonly) BOOL isGameOver;

// The current winner, or T3PlayerNone if either the game is
//  not over or the game ended in a draw.
@property (nonatomic, readonly) T3Player winner;

// Returns an array representing the occupation (or lack thereof)
//  of each square, one row at a time, from left to right, top
//  to bottom.
// e.g., None, None, None, X, X, O, None, None, O
// This is primarily for testing purposes.
@property (nonatomic, readonly) NSArray *gameBoard;

// The number of occupied squares in the game.
@property (nonatomic, readonly) NSUInteger occupiedSquareCount;

// Resets the game.
- (void)resetGame;

// Plays the square at the given zero-based row/col
//  on behalf of the player whose turn it is.
- (void)playSquareOnRow:(NSUInteger)row col:(NSUInteger)col;

// Returns the player occupying the square at the specified row and column.
- (T3Player)playerOccupyingRow:(NSUInteger)row col:(NSUInteger)col;

@end
