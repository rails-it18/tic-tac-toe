//
//  T3ComputerPlayer.m
//  TicTacToe
//
//  Created by Ethan Jud on 2/1/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "T3ComputerPlayer.h"

static void *kObservationContext = &kObservationContext;

@interface T3ComputerPlayer ()

@property (nonatomic, strong) T3Game *game;
@property (nonatomic, readwrite) T3Player player;

@property (nonatomic, strong) NSDictionary *nextResponseMap;

// Tracks whether the game is currently flipping the rows/cols
//  to look at the possible moves.
@property (nonatomic) BOOL usingFlippedPerspective;

@property (nonatomic) BOOL diagonalPerspectiveEvaluated;
@property (nonatomic) BOOL rotationalPerspectiveEvaluated;

@end

@implementation T3ComputerPlayer

#pragma mark - Object lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _player = T3PlayerNone;
        _usingFlippedPerspective = NO;
        _diagonalPerspectiveEvaluated = NO;
        _rotationalPerspectiveEvaluated = NO;
    }
    return self;
}

- (void)dealloc
{
    [_game removeObserver:self forKeyPath:@"currentPlayer"];
    [_game release];
    
    [super dealloc];
}

#pragma mark - Static properties

// The board is guaranteed to be assymetrical about the
//  diagonal (where row == col) after the first response
//  as X.
+ (NSArray *)optimalMoveTreeForPlayerX
{
    id null = [NSNull null];
    
    // After the first move, if O plays on the first row
    //  (on a perspective-corrected board) we are guaranteed
    //  to win (via forking) by using the following subtree of moves.
    id commonFork = @[@010, @{
                        @020 : @[@011, @{
                            @022 : @012, // win
                            null : @022 // win
                        }],
                        null : @020 // win
                    }];
    
    return @[@000, @{
        @001 : commonFork,
        @002 : commonFork,
        @012 : @[@011, @{
            @022 : @[@002, @{
                @020 : @001, // win
                null : @020 // win
            }],
            null : @022 // win
        }],
        @022 : @[@002, @{
            @001 : @[@020, @{
                @011 : @010, // win
                null : @011 // win
            }],
            null : @001 // win
        }],
    
        // O's only safe response
        @011 : @[@001, @{
            // O must block X's win
            @002 : @[@020, @{
                // O must block X's win
                @010 : @012, // draw no matter where O moves
                null : @010 // win
            }],
            null : @002 // win
        }],
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
                    @012 : @022, // draw
                    null : @012 // win
                }],
                null : @020 // win
            }],
            // X in Top-right. Block X's top-row win
            @002 : @[@001, @{
                @021 : @[@010, @{
                    @012 : @022, // draw
                    null : @012 // win
                }],
                null : @021 // win
            }],
            // X in Middle-right. Create a middle-column threat
            @012 : @[@001, @{
                @021 : @[@020, @{
                    @002 : @022, // draw
                    null : @002 // win
                }],
                null : @021 // win
            }],
            // X in Bottom-right. Create a middle-column threat
            @022 : @[@001, @{
                @021 : @[@020, @{
                    @002 : @012, // draw
                    null : @002 // win
                }],
                null : @021 // win
            }]
        }],
    
        // X Starts in top-middle. Respond with O in the middle.
        @001 : @[@011, @{
            // X in top-right. Block X's top-row win
            @002 : @[@000, @{
                @022 : @[@012, @{
                    @010 : @020, // draw
                    null : @010 // win
                }],
                null : @022 // win
            }],
            // X in middle-right. Create a diagonal threat.
            @012 : @[@002, @{
                @020 : @[@000, @{
                    @022 : @021, // draw
                    null : @022 // win
                }],
                null : @020 // win
            }],
            // X in bottom-right. Create a middle-row threat.
            @022 : @[@012, @{
                @010 : @[@020, @{
                    @002 : @000, // draw
                    null : @002 // win
                }],
                null : @010 // win
            }],
            // X in bottom-middle. We can fork the opponent.
            @022 : @[@012, @{
                @010 : @[@022, @{
                    @000 : @002, // win
                    null : @000 // win
                }],
                null : @010 // win
            }],
    
            //TODO: Handle left column by flipping perspective horizontally
        }]
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
    self.usingFlippedPerspective = NO;
    self.diagonalPerspectiveEvaluated = NO;
    self.rotationalPerspectiveEvaluated = NO;
}

- (BOOL)takeTurnFromMappedValue:(NSUInteger)value
{
    NSUInteger row = 0;
    NSUInteger col = 0;
    [self scanTreeMove:value yieldingRow:&row col:&col];
    
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
    NSLog(@"Computer is sad. It lost track of the game.");
    
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
    [[tree retain] autorelease];
    self.nextResponseMap = nil;
    
    if (tree.count == 0) {
        NSAssert(0, @"Computer is sad. It lost track of the game.");
        [self takeAnyTurn];
        return;
    }
    
    NSUInteger valForMove = [[tree objectAtIndex:0] unsignedIntegerValue];
    if (![self takeTurnFromMappedValue:valForMove]) {
        NSLog(@"Computer is sad. It lost track of the game.");
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
    
    if (self.usingFlippedPerspective) {
        NSUInteger temp = row;
        row = col;
        col = temp;
    }
    
    return row * 8 + col;
}

// Extracts a row and column out of a perspective-corrected move that was
//  taken from one of the optimal move trees.
- (void)scanTreeMove:(NSUInteger)treeMove yieldingRow:(NSUInteger *)pRow col:(NSUInteger *)pCol
{
    NSUInteger row = treeMove / 8;
    NSUInteger col = treeMove % 8;
    NSAssert(row < 3 && col < 3, @"Invalid tree move passed to scanTreeMove:yieldingRow:col:");
    
    if (self.usingFlippedPerspective) {
        NSUInteger temp = row;
        row = col;
        col = temp;
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
    
    NSUInteger moveByOpponent = [self treeMoveForRow:row col:col];
    id response = [self.nextResponseMap objectForKey:@(moveByOpponent)];
    
    if (!response) {
        response = [self.nextResponseMap objectForKey:[NSNull null]];
    }
    
    if (response) {
        if ([response isKindOfClass:[NSNumber class]]) {
            // Last turn. It better put us in a good position.
            if ([self takeTurnFromMappedValue:[response unsignedIntegerValue]]) {
                self.nextResponseMap = nil;
                return;
            }
        }
        else if ([response isKindOfClass:[NSArray class]]) {
            [self takeTurnForTree:response];
            return;
        }
    }

    NSLog(@"Computer is sad. It lost track of the game.");
    self.nextResponseMap = nil;
    [self takeAnyTurn];
}

#pragma mark - Game Observing

- (void)moveMadeInGame:(NSNotification *)notification
{
    NSNumber *playerNumber = [notification.userInfo valueForKey:T3TurnPlayerKey];
    T3Player player = playerNumber.unsignedIntegerValue;
    if (player == self.player) {
        // Ignore plays made by ourself
        return;
    }
    
    NSUInteger row = [[notification.userInfo valueForKey:T3TurnRowKey] unsignedIntegerValue];
    NSUInteger col = [[notification.userInfo valueForKey:T3TurnColKey] unsignedIntegerValue];
    
    // Perspective corrections, if applicable. Note that these
    //  corrections may happen after a human or computer player
    //  made a move in the game.
    
    if (!self.rotationalPerspectiveEvaluated && (row != 1 || col != 1)) {
        //TODO:
        // The first non-center square played determines the extent to which
        //  we are rotating our perspective.
    }
    
    if (!self.diagonalPerspectiveEvaluated && row != col) {
        // After applying our rotational perspective,
        //  the first square played not on the top-left/bottom-right diagonal
        //  determines whether we are flipping our rows/cols for our perspetive.
        if (row > col) {
            self.usingFlippedPerspective = YES;
        }
        
        self.diagonalPerspectiveEvaluated = YES;
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
