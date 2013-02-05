//
//  T3Game.m
//  TicTacToe
//
//  Created by Ethan Jud on 1/30/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "T3Game.h"

NSString *const T3TurnTakenInGameNotification = @"T3TurnTakenInGameNotification";
NSString *const T3TurnPlayerKey = @"T3TurnPlayerKey";
NSString *const T3TurnRowKey = @"T3TurnRowKey";
NSString *const T3TurnColKey = @"T3TurnColKey";

@interface T3Game () {
    T3Player _board[3][3];
}

// Writable implementations of public properties
@property (nonatomic, readwrite) T3Player currentPlayer;
@property (nonatomic, readwrite) BOOL isGameOver;
@property (nonatomic, readwrite) T3Player winner;
@property (nonatomic, readwrite) NSUInteger occupiedSquareCount;

@end

@implementation T3Game

@dynamic gameBoard;

#pragma mark - Object lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        [self resetGame];
    }
    return self;
}

#pragma mark - Game State

- (NSArray *)gameBoard
{
    NSMutableArray *board = [NSMutableArray array];
    for (NSUInteger row = 0; row < 3; ++row) {
        for (NSUInteger col = 0; col < 3; ++col) {
            [board addObject:@(_board[row][col])];
        }
    }
    return board;
}

- (T3Player)playerOccupyingRow:(NSUInteger)row col:(NSUInteger)col
{
    if (row >= 3 || col >= 3) {
        NSAssert(0, @"Requested square out of bounds.");
        return T3PlayerNone;
    }
    
    return _board[row][col];
}

#pragma mark - Game Actions

- (void)resetGame
{
    [self willChangeValueForKey:@"gameBoard"];
    for (NSUInteger row = 0; row < 3; ++row) {
        for (NSUInteger col = 0; col < 3; ++col) {
            _board[row][col] = T3PlayerNone;
        }
    }
    [self didChangeValueForKey:@"gameBoard"];

    self.occupiedSquareCount = 0;
    self.currentPlayer = T3PlayerX;
    self.isGameOver = NO;
    self.winner = T3PlayerNone;
}

- (void)playSquareOnRow:(NSUInteger)row col:(NSUInteger)col
{
    if (row >= 3 || col >= 3) {
        NSAssert(0, @"Attempted to play a square out of bounds.");
        return;
    }
    
    if (self.currentPlayer == T3PlayerNone) {
        NSAssert(0, @"Attempted to play a square when there is no current player.");
    }

    if (_board[row][col] != T3PlayerNone) {
        NSAssert(0, @"Attempted to play a square that has already been played.");
        return;
    }
    
    // Populate the square
    [self willChangeValueForKey:@"gameBoard"];
    _board[row][col] = self.currentPlayer;
    [self didChangeValueForKey:@"gameBoard"];
    
    NSDictionary *notificationUserInfo = @{
        T3TurnPlayerKey : @(self.currentPlayer),
        T3TurnRowKey : @(row),
        T3TurnColKey : @(col)
    };
    [[NSNotificationCenter defaultCenter] postNotificationName:T3TurnTakenInGameNotification
                                                        object:self
                                                      userInfo:notificationUserInfo];
    
    ++self.occupiedSquareCount;
    
    // Determine whether the game is over.
    
    // First, check for winning conditions. A winner based on this move
    //  must necessarily include the current square.
    T3Player winner = ^T3Player() {
        // Diagonal top-left to bottom-right
        T3Player candidate = _board[0][0];
        if (candidate != T3PlayerNone && candidate == _board[1][1] && candidate == _board[2][2]) {
            return candidate;
        }
        
        // Diagonal top-right to bottom-left
        candidate = _board[0][2];
        if (candidate != T3PlayerNone && candidate == _board[1][1] && candidate == _board[2][0]) {
            return candidate;
        }
        
        // Horizontal three-in-a-row, must include the current row.
        candidate = _board[row][0];
        if (candidate != T3PlayerNone && candidate == _board[row][1] && candidate == _board[row][2]) {
            return candidate;
        }
        
        // Vertical three-in-a-row, must include the current column
        candidate = _board[0][col];
        if (candidate != T3PlayerNone && candidate == _board[1][col] && candidate == _board[2][col]) {
            return candidate;
        }
        
        return T3PlayerNone;
    }();
    
    self.winner = winner;
    if (winner != T3PlayerNone) {
        self.isGameOver = YES;
    }
    else {
        self.isGameOver = ^BOOL() {
            for (NSUInteger row = 0; row < 3; ++row) {
                for (NSUInteger col = 0; col < 3; ++col) {
                    if (_board[row][col] == T3PlayerNone) {
                        // An empty square. Game is not over.
                        return NO;
                    }
                }
            }
            
            // All squares occupied. Game is over (and a draw).
            return YES;
        }();
    }
    
    if (self.isGameOver) {
        self.currentPlayer = T3PlayerNone;
    }
    else {
        // Next player
        self.currentPlayer = (self.currentPlayer == T3PlayerX ? T3PlayerO : T3PlayerX);
    }
}

@end
