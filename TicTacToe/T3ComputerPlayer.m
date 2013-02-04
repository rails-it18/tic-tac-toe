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

@end

@implementation T3ComputerPlayer

#pragma mark - Object lifecycle

- (id)init
{
    self = [super init];
    if (self) {
        _player = T3PlayerNone;
    }
    return self;
}

- (void)dealloc
{
    [_game removeObserver:self forKeyPath:@"currentPlayer"];
    [_game release];
    
    [super dealloc];
}

#pragma mark - Properties

- (void)setGame:(T3Game *)game
{
    [_game removeObserver:self forKeyPath:@"currentPlayer"];
    _game = game;
    [_game addObserver:self
            forKeyPath:@"currentPlayer"
               options:0
               context:kObservationContext];
}

#pragma mark - Computer Player

- (void)startPlayingGame:(T3Game *)game asPlayer:(T3Player)player
{
    [self stopPlaying];
    self.game = game;
    self.player = player;
    
    if (self.game.currentPlayer == self.player) {
        [self takeTurn];
    }
}

- (void)stopPlaying
{
    self.game = nil;
    self.player = T3PlayerNone;
}

- (void)takeTurn
{
    NSAssert(self.game.currentPlayer == self.player, @"Computer attempted to play out of turn.");
    
    if (self.player == T3PlayerX) {
        if (self.game.occupiedSquareCount == 0) {
            [self.game playSquareOnRow:0 col:0];
            return;
        }
    }
    
    if (![self.game playerOccupyingRow:1 col:1]) {
        // If the center square is not occupied, play that first.
        [self.game playSquareOnRow:1 col:1];
        return;
    }
    
    // Otherwise, for now, find the first unoccupied square.
    for (NSUInteger row = 0; row < 3; ++row) {
        for (NSUInteger col = 0; col < 3; ++col) {
            if ([self.game playerOccupyingRow:row col:col] == T3PlayerNone) {
                [self.game playSquareOnRow:row col:col];
                return;
            }
        }
    }
}

#pragma mark - Game Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != kObservationContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    NSAssert(object == self.game, @"Observed object should be the game object.");
    
    if ([keyPath isEqualToString:@"currentPlayer"]) {
        if (self.game.currentPlayer == self.player) {
            if (self.player == T3PlayerNone) {
                // Do nothing.
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
                
                [self takeTurn];
            });
        }
    }
}

@end
