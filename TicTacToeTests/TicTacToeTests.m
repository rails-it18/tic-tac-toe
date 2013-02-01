//
//  TicTacToeTests.m
//  TicTacToeTests
//
//  Created by Ethan Jud on 1/30/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "TicTacToeTests.h"
#import "T3Game.h"

@implementation TicTacToeTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testNewGame
{
    T3Game *game = [[[T3Game alloc] init] autorelease];
    
    STAssertFalse(game.isGameOver, @"New game should not be over.");
    STAssertEquals(game.currentPlayer, T3PlayerX, @"First player should be X");
    STAssertEquals(game.winner, T3PlayerNone, @"New game should have no winner.");
}

- (void)testTurns
{
    T3Game *game = [[[T3Game alloc] init] autorelease];
    
    [game playSquareOnRow:1 col:1];
    STAssertEquals(game.currentPlayer, T3PlayerO, @"Turn should change after valid square played.");
    
    [game playSquareOnRow:1 col:1];
    STAssertEquals(game.currentPlayer, T3PlayerO, @"Turn should not change after invalid square played.");
    
    [game playSquareOnRow:0 col:1];
    STAssertEquals(game.currentPlayer, T3PlayerX, @"Turn should change after valid square played.");
    
    STAssertFalse(game.isGameOver, @"Game should not be over without 3 in a row.");
}

- (void)testWinner
{
    T3Game *game = [[[T3Game alloc] init] autorelease];
    
    [game playSquareOnRow:0 col:0]; // X
    [game playSquareOnRow:0 col:2]; // O
    
    [game playSquareOnRow:1 col:0]; // X
    [game playSquareOnRow:1 col:1]; // O
    
    /* Current game:
     *  X O
     *  XO
     *
     */
    
    STAssertFalse(game.isGameOver, @"Game should not be over yet.");
    
    [game playSquareOnRow:2 col:0]; // X
    /* Current game:
     *  X O
     *  XO
     *  X
     */
    
    STAssertTrue(game.isGameOver, @"Game should be over with three in a row.");
    STAssertEquals(game.currentPlayer, T3PlayerNone, @"It should be nobody's turn.");
    STAssertEquals(game.winner, T3PlayerX, @"X should be the winner");
    
    [game resetGame];
    STAssertFalse(game.isGameOver, @"Game should be reset.");
    STAssertEquals(game.currentPlayer, T3PlayerX, @"X plays first.");
    STAssertEquals(game.winner, T3PlayerNone, @"Game should be reset and there should be no winner.");
}

- (void)testSecondPlayerWinner
{
    T3Game *game = [[[T3Game alloc] init] autorelease];
    
    [game playSquareOnRow:0 col:0]; // X
    [game playSquareOnRow:0 col:2]; // O
    
    [game playSquareOnRow:1 col:0]; // X
    [game playSquareOnRow:1 col:1]; // O
    
    /* Current game:
     *  X O
     *  XO
     *
     */
    
    [game playSquareOnRow:1 col:2]; // X
    /* Current game:
     *  X O
     *  XOX
     *
     */
    
    [game playSquareOnRow:2 col:0]; // O
    /* Current game:
     *  X O
     *  XOX
     *  O
     */
    
    STAssertEquals(game.winner, T3PlayerO, @"O should be the winner.");
}

- (void)testGameState
{
    T3Game *game = [[[T3Game alloc] init] autorelease];
    
    [game playSquareOnRow:0 col:0]; // X
    [game playSquareOnRow:0 col:2]; // O
    
    [game playSquareOnRow:1 col:0]; // X
    [game playSquareOnRow:1 col:1]; // O
    /* Current game:
     *  X O
     *  XO
     *
     */
    
    [game playSquareOnRow:1 col:2]; // X
    /* Current game:
     *  X O
     *  XOX
     *
     */
    
    NSArray *board = game.gameBoard;
    NSArray *expected = @[
        @(T3PlayerX), @(T3PlayerNone), @(T3PlayerO),
        @(T3PlayerX), @(T3PlayerO), @(T3PlayerX),
        @(T3PlayerNone), @(T3PlayerNone), @(T3PlayerNone)
    ];
    STAssertEqualObjects(board, expected, @"Board should be expected");
}

@end
