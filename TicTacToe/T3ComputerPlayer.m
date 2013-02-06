//
//  T3ComputerPlayer.m
//  TicTacToe
//
//  Created by Ethan Jud on 2/1/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "T3ComputerPlayer.h"

static void *kObservationContext = &kObservationContext;

// Possible transformations used by the preferred move trees
typedef enum {
    T3PerspectiveTransformationFlipDiagonally,
    T3PerspectiveTransformationFlipHorizontally,
    T3PerspectiveTransformationRotate1,
    T3PerspectiveTransformationRotate2,
    T3PerspectiveTransformationRotate3
} T3PerspectiveTransformation;


@interface T3ComputerPlayer ()

// The game that the computer is playing
@property (nonatomic, strong) T3Game *game;
// The player that the computer is playing as
@property (nonatomic, readwrite) T3Player player;

// Tracks the next map to be used to determine the move in
//  response to the opponent's next move.
@property (nonatomic, strong) NSDictionary *nextResponseMap;

// Tracks whether the game is currently flipping the rows/cols
//  to look at the possible moves.
@property (nonatomic, strong) NSMutableArray *perspectiveTransformations;

@end

@implementation T3ComputerPlayer

#pragma mark - Object lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _player = T3PlayerNone;
        _perspectiveTransformations = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_game removeObserver:self forKeyPath:@"currentPlayer"];
    [_game release];
    
    [_perspectiveTransformations release];
    
    [super dealloc];
}

#pragma mark - Static properties

// Possible objects found in move trees:
// - "Response Map": a dictionary whose keys represent
//   possible opponent moves*, and whose values are either:
//   1. An array of size 1, containing only the next move.
//      If this is the case, the next move should be sufficient
//      to either win or put the game in a state from which only
//      a draw is possible.
//   2. An array of size 2. The first object is the next move,
//      and the second object is another Response Map.
//   3. A number. The number represents one of the values
//      for T3PerspectiveTransformation. When this is encountered,
//      it means that the perspective of the board should be transformed
//      as such so that another object from the same response map
//      may be obtained.
//   * If [NSNull null] exists as a key in the dictionary, this is
//      used to indicate "all other moves" by the opponent.
// - "Move": a move is an NSNumber whose value is an unsigned integer.
//      The digits in the octal representation of this integer represent
//      the row and column of the move.

// A move tree for player X, starting with X's first move.
// This means that the return type is an array, with a move
//  as the first element and a response map as the second
//  element.
+ (NSArray *)optimalMoveTreeForPlayerX
{
    id null = [NSNull null];
    
    // After the first move, if O plays on the first row
    //  (on a perspective-corrected board) we are guaranteed
    //  to win (via forking) by using the following subtree of moves.
    id commonFork = @[@010, @{
                        @020 : @[@011, @{
                            @022 : @[@012], // win
                            null : @[@022] // win
                        }],
                        null : @[@020] // win
                    }];
    
    return @[@000, @{
        @001 : commonFork,
        @002 : commonFork,
        @012 : @[@011, @{
            @022 : @[@002, @{
                @020 : @[@001], // win
                null : @[@020] // win
            }],
            null : @[@022] // win
        }],
        @022 : @[@002, @{
            @001 : @[@020, @{
                @011 : @[@010], // win
                null : @[@011] // win
            }],
            null : @[@001] // win
        }],
    
        // O's only safe response
        @011 : @[@001, @{
            // O must block X's win
            @002 : @[@020, @{
                // O must block X's win
                @010 : @[@012], // draw no matter where O moves
                null : @[@010] // win
            }],
            null : @[@002] // win
        }],
    
        // Otherwise, we need to flip our perspective diagonally
        null : @(T3PerspectiveTransformationFlipDiagonally)
    }];
}

+ (NSDictionary *)optimalMoveTreeForPlayerO
{
    id null = [NSNull null];
    
    return @{
        // X Starts in top-left. Respond with O in the middle.
        @000 : @[@011, @{
            // X in Top-middle. Block X's top-row win
            @001 : @[@002, @{
                @020 : @[@010, @{
                    @012 : @[@022], // draw
                    null : @[@012] // win
                }],
                null : @[@020] // win
            }],
            // X in Top-right. Block X's top-row win
            @002 : @[@001, @{
                @021 : @[@010, @{
                    @012 : @[@022], // draw
                    null : @[@012] // win
                }],
                null : @[@021] // win
            }],
            // X in Middle-right. Create a middle-column threat
            @012 : @[@001, @{
                @021 : @[@020, @{
                    @002 : @[@022], // draw
                    null : @[@002] // win
                }],
                null : @[@021] // win
            }],
            // X in Bottom-right. Create a middle-column threat
            @022 : @[@001, @{
                @021 : @[@020, @{
                    @002 : @[@012], // draw
                    null : @[@002] // win
                }],
                null : @[@021] // win
            }],
    
            // Otherwise, we need a perspective change
            null : @(T3PerspectiveTransformationFlipDiagonally)
        }],
    
        // X Starts in top-middle. Respond with O in the middle.
        @001 : @[@011, @{
            // X in top-right. Block X's top-row win
            @002 : @[@000, @{
                @022 : @[@012, @{
                    @010 : @[@020], // draw
                    null : @[@010] // win
                }],
                null : @[@022] // win
            }],
            // X in middle-right. Create a diagonal threat.
            @012 : @[@002, @{
                @020 : @[@000, @{
                    @022 : @[@021], // draw
                    null : @[@022] // win
                }],
                null : @[@020] // win
            }],
            // X in bottom-right. Create a middle-row threat.
            @022 : @[@012, @{
                @010 : @[@020, @{
                    @002 : @[@000], // draw
                    null : @[@002] // win
                }],
                null : @[@010] // win
            }],
            // X in bottom-middle. We can fork the opponent.
            @021 : @[@012, @{
                @010 : @[@022, @{
                    @000 : @[@002], // win
                    null : @[@000] // win
                }],
                null : @[@010] // win
            }],
    
            // Handle left column by flipping perspective horizontally
            null : @(T3PerspectiveTransformationFlipHorizontally)
        }],
    
        // X starts in the middle. Respond with O in the top-left
        @011 : @[@000, @{
            // X in the top-middle. Block X's middle-column threat
            @001 : @[@021, @{
                // X in the top-right. We can fork the opponent
                @002 : @[@020, @{
                    @010 : @[@022], // win
                    null : @[@010] // win
                }],
                // X in the middle-right. Block the middle-row threat
                @012 : @[@010, @{
                    @020 : @[@002], // draw
                    null : @[@020] // win
                }],
                // X in the bottom-right. Create a left-column threat
                @022 : @[@010, @{
                    @020 : @[@002], // draw
                    null : @[@020] // win
                }],
                // X in the middle-left. Block the middle-row threat and force a draw
                @010 : @[@012, @{
                    @002 : @[@020], // draw
                    null : @[@002] // draw
                }],
                // X in the bottom-left. Block the diagonal threat and force a draw
                @020 : @[@002, @{
                    @010 : @[@012], // draw
                    null : @[@010] // draw
                }]
            }],
            // X in the top-right. Block the diagonal threat
            @002 : @[@020, @{
                @010 : @[@012, @{
                    @001 : @[@021], // draw
                    null : @[@001] // draw
                }],
                null : @[@010] // win
            }],
            // X in the middle-right. Block the horizontal threat
            @012 : @[@010, @{
                @020 : @[@002, @{
                    @001 : @[@021], // draw
                    null : @[@001] // win
                }],
                null : @[@020] // win
            }],
            // X in the bottom-right. Create a left-column threat
            @022 : @[@020, @{
                @010 : @[@012, @{
                    @001 : @[@021], // draw
                    null : @[@001] // draw
                }],
                null : @[@010] // win
            }],
    
            // Otherwise, we need a perspective change
            null : @(T3PerspectiveTransformationFlipDiagonally)
        }],
    
        // Any other moves by X require a perspective change.
        @010 : @(T3PerspectiveTransformationRotate1),
        @020 : @(T3PerspectiveTransformationRotate1),
        @021 : @(T3PerspectiveTransformationRotate2),
        @022 : @(T3PerspectiveTransformationRotate2),
        @012 : @(T3PerspectiveTransformationRotate3),
        @002 : @(T3PerspectiveTransformationRotate3)
    };
}

#pragma mark - Properties

- (void)setGame:(T3Game *)game
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:T3TurnTakenInGameNotification
                                                  object:_game];
    _game = game;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moveMadeInGame:)
                                                 name:T3TurnTakenInGameNotification
                                               object:_game];
}

#pragma mark - Computer Player

- (void)startPlayingGame:(T3Game *)game asPlayer:(T3Player)player
{
    [self stopPlaying];

    NSAssert(player != T3PlayerNone,
             @"Computer was asked to play a game as nobody.");
    
    self.game = game;
    self.player = player;
    
    // The computer player's logic depends on remembering the game state.
    // If the player is started partway through a game, it will not play
    //  strategically.
    NSAssert(self.game.occupiedSquareCount == 0,
             @"Computer player started playing partway through a game!");
    
    if (self.game.currentPlayer == self.player) {
        [self takeTurnWithoutHistory];
    }
}

- (void)stopPlaying
{
    self.game = nil;
    self.player = T3PlayerNone;
    [self.perspectiveTransformations removeAllObjects];
}

// Takes a turn from the specified mapped value. The value is a move
//  taken directly from one of the move trees.
- (BOOL)takeTurnFromMappedValue:(NSUInteger)value
{
    NSUInteger row = 0;
    NSUInteger col = 0;
    [self convertTreeMove:value toRow:&row col:&col];
    
    if ([self.game playerOccupyingRow:row col:col] == T3PlayerNone) {
        [self.game playSquareOnRow:row col:col];
        return YES;
    }
    else {
        return NO;
    }
}

// Takes a turn at any available square, without
//  any strategy.
- (void)takeAnyTurn
{
    // Find the first unoccupied square.
    for (NSUInteger row = 0; row < 3; ++row) {
        for (NSUInteger col = 0; col < 3; ++col) {
            if ([self.game playerOccupyingRow:row col:col] == T3PlayerNone) {
                [self.game playSquareOnRow:row col:col];
                return;
            }
        }
    }
}

// Takes a turn without "remembering" the history of
//  the game, if there is any. Typically this should only
//  happen on the first move as player X.
- (void)takeTurnWithoutHistory
{
    NSAssert(self.game.currentPlayer == self.player, @"Computer attempted to play out of turn.");
    
    // wherever we are, if we have a response map
    //  it is no longer valid.
    self.nextResponseMap = nil;
    
    if (self.game.occupiedSquareCount == 0 && self.player == T3PlayerX) {
        // Find optimal move tree
        [self takeTurnForTree:[[self class] optimalMoveTreeForPlayerX]];
        return;
    }
    
    // Oops. We have to just take any blind turn...
    NSLog(@"Computer is confused. :(");
    
    if (![self.game playerOccupyingRow:1 col:1]) {
        // If the center square is not occupied, play that first.
        [self.game playSquareOnRow:1 col:1];
        return;
    }
}

// Takes a turn for the given tree.
// The provided array should be of the form [ move, response dictionary ]
- (void)takeTurnForTree:(NSArray *)tree
{
    if (tree.count == 0) {
        NSAssert(0, @"Computer is confused. :(");
        [self takeAnyTurn];
        return;
    }
    
    NSUInteger valForMove = [[tree objectAtIndex:0] unsignedIntegerValue];
    if (![self takeTurnFromMappedValue:valForMove]) {
        NSLog(@"Computer is confused. :(");
        [self takeAnyTurn];
        return;
    }
    
    if (tree.count >= 2) {
        id secondObj = [tree objectAtIndex:1];
        if ([secondObj isKindOfClass:[NSDictionary class]]) {
            self.nextResponseMap = secondObj;
            return;
        }
    }
}

// Returns a perspective-corrected move for the given row/col to be used
//  in one of the optimal move trees.
- (NSUInteger)treeMoveForRow:(NSUInteger)row col:(NSUInteger)col
{
    NSAssert(row < 3 && col < 3, @"Invalid row/col provided to treeMoveForRow:col:");
    
    for (NSNumber *val in self.perspectiveTransformations) {
        T3PerspectiveTransformation transformation = val.unsignedIntegerValue;
        switch (transformation) {
            case T3PerspectiveTransformationFlipDiagonally:
            {
                NSUInteger temp = row;
                row = col;
                col = temp;
                break;
            }
            case T3PerspectiveTransformationFlipHorizontally:
                col = 2 - col;
                break;
            case T3PerspectiveTransformationRotate1:
            {
                NSUInteger newRow = col;
                NSUInteger newCol = 2 - row;
                row = newRow;
                col = newCol;
                break;
            }
            case T3PerspectiveTransformationRotate2:
                row = 2 - row;
                col = 2 - col;
                break;
            case T3PerspectiveTransformationRotate3:
            {
                NSUInteger newRow = 2 - col;
                NSUInteger newCol = row;
                row = newRow;
                col = newCol;
                break;
            }
        }
    }
    
    return row * 8 + col;
}

// Extracts a row and column out of a perspective-corrected move that was
//  taken from one of the optimal move trees.
- (void)convertTreeMove:(NSUInteger)treeMove toRow:(NSUInteger *)pRow col:(NSUInteger *)pCol
{
    NSUInteger row = treeMove / 8;
    NSUInteger col = treeMove % 8;
    NSAssert(row < 3 && col < 3, @"Invalid tree move passed to convertTreeMove:toRow:col:");
    
    // Iterate through the perspective transformations in reverse
    for (NSUInteger i = self.perspectiveTransformations.count; i > 0; --i) {
        T3PerspectiveTransformation transformation = [[self.perspectiveTransformations objectAtIndex:(i-1)]
                                                      unsignedIntegerValue];
        switch (transformation) {
            case T3PerspectiveTransformationFlipDiagonally:
            {
                NSUInteger temp = row;
                row = col;
                col = temp;
                break;
            }
            case T3PerspectiveTransformationFlipHorizontally:
                col = 2 - col;
                break;
            case T3PerspectiveTransformationRotate1:
            {
                NSUInteger newRow = 2 - col;
                NSUInteger newCol = row;
                row = newRow;
                col = newCol;
                break;
            }
            case T3PerspectiveTransformationRotate2:
                row = 2 - row;
                col = 2 - col;
                break;
            case T3PerspectiveTransformationRotate3:
            {
                NSUInteger newRow = col;
                NSUInteger newCol = 2 - row;
                col = newCol;
                row = newRow;
                break;
            }
        }
    }
    
    if (pRow) {
        *pRow = row;
    }
    
    if (pCol) {
        *pCol = col;
    }
}

// Takes a turn in response to the opponent moving at the
//  specified square.
- (void)takeTurnInResponseToOpponentAtRow:(NSUInteger)row col:(NSUInteger)col
{
    if (self.player == T3PlayerO && self.game.occupiedSquareCount == 1) {
        // X just moved, and now it's our turn.
        
        self.nextResponseMap = [[self class] optimalMoveTreeForPlayerO];
    }

    if (self.nextResponseMap == nil) {
        // This means one of the following is true:
        //    1. We have exhausted a branch in the optimal move
        //       tree, and we can now make any turn without losing.
        // or 2. A logic error occurred on a previous turn,
        //       and we don't know what to do.
        [self takeAnyTurn];
        return;
    }

    id (^getResponse)() = ^{
        NSUInteger moveByOpponent = [self treeMoveForRow:row col:col];
        id response = [self.nextResponseMap objectForKey:@(moveByOpponent)];
        if (!response) {
            response = [self.nextResponseMap objectForKey:[NSNull null]];
        }
        // We are returning a subtree, so we need to retain this for our use
        //  in case the parent tree is deallocated.
        return [[response retain] autorelease];
    };
    
    id response = getResponse();
    if ([response isKindOfClass:[NSNumber class]]) {
        // This should be a transofmration command. We want to transform the board
        //  and then find the response again
        [self.perspectiveTransformations addObject:response];
        response = getResponse();
    }
    
    self.nextResponseMap = nil;
    
    if ([response isKindOfClass:[NSArray class]]) {
        [self takeTurnForTree:response];
        return;
    }

    NSLog(@"Computer is confused. :(");
    [self takeAnyTurn];
}

#pragma mark - Game Observing

// Observes moves made in the game, which we then respond to if it's our turn.
- (void)moveMadeInGame:(NSNotification *)notification
{
    NSUInteger row = [[notification.userInfo valueForKey:T3TurnRowKey] unsignedIntegerValue];
    NSUInteger col = [[notification.userInfo valueForKey:T3TurnColKey] unsignedIntegerValue];
    
    NSNumber *playerNumber = [notification.userInfo valueForKey:T3TurnPlayerKey];
    T3Player player = playerNumber.unsignedIntegerValue;
    if (player == self.player) {
        // Ignore our own moves.
        return;
    }
    
    // It's the computer's turn.
    // "Think" for just a little bit.
    double delayInSeconds = 0.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (self.game.currentPlayer != self.player || self.player == T3PlayerNone) {
            // Abort!
            return;
        }
        
        [self takeTurnInResponseToOpponentAtRow:row col:col];
    });
}

@end
