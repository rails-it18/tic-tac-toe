//
//  T3ViewController.m
//  TicTacToe
//
//  Created by Ethan Jud on 1/30/13.
//  Copyright (c) 2013 Ethan Jud. All rights reserved.
//

#import "T3ViewController.h"
#import "T3Game.h"

static void* kObservationContext = &kObservationContext;

static NSUInteger kRowCount = 3;
static NSUInteger kColCount = 3;

@interface T3ViewController () <UIAlertViewDelegate>

@property (retain, nonatomic) IBOutlet UIView *gameBoardView;

// The index of a button in this array should be the same as its tag,
// which should be equal to its row * kColCount + col
@property (strong, nonatomic) NSArray *gameBoardButtons;

@property (strong, nonatomic) T3Game *game;

@end

@implementation T3ViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize the game
    _game = [[T3Game alloc] init];
    
    // Observe stuff
    [self.game addObserver:self
                forKeyPath:@"currentPlayer"
                   options:0
                   context:kObservationContext];
    
    [self.game addObserver:self
                forKeyPath:@"isGameOver"
                   options:0
                   context:kObservationContext];
    
    // Initialize the game board buttons.
    NSMutableArray *boardButtons = [NSMutableArray array];
    for (NSUInteger i = 0; i < kRowCount * kColCount; ++i) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:48.0];
        button.tag = i;
        
        [button addTarget:self
                   action:@selector(boardButtonTapped:)
         forControlEvents:UIControlEventTouchUpInside];
        
        [boardButtons addObject:button];
        
        [self.gameBoardView addSubview:button];
    }
    
    self.gameBoardButtons = boardButtons;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGFloat buttonWidth = self.gameBoardView.bounds.size.width / kColCount;
    CGFloat buttonHeight = self.gameBoardView.bounds.size.height / kRowCount;
    
    for (UIButton *button in self.gameBoardButtons) {
        NSUInteger row = button.tag / kColCount;
        NSUInteger col = button.tag % kColCount;
        
        button.frame = CGRectMake(col * buttonWidth,
                                  row * buttonHeight,
                                  buttonWidth,
                                  buttonHeight);
        [button.titleLabel sizeToFit];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [self.game removeObserver:self forKeyPath:@"currentPlayer"];
    [self.game removeObserver:self forKeyPath:@"isGameOver"];
    
    [_gameBoardView release];
    [_gameBoardButtons release];
    [_game release];
    
    [super dealloc];
}

#pragma mark - Game UI

- (void)refreshBoard
{
    for (NSUInteger row = 0; row < kRowCount; ++row) {
        for (NSUInteger col = 0; col < kColCount; ++col) {
            [self refreshSquareAtRow:row col:col];
        }
    }
}

- (void)refreshSquareAtRow:(NSUInteger)row col:(NSUInteger)col
{
    NSUInteger index = row * kColCount + col;
    UIButton *button = [self.gameBoardButtons objectAtIndex:index];
    
    // Update the title label
    NSString *title = ^NSString *() {
        switch ([self.game playerOccupyingRow:row col:col]) {
            case T3PlayerNone:
                return @"";
            case T3PlayerX:
                return @"X";
            case T3PlayerO:
                return @"O";
        }
    }();
    [button setTitle:title forState:UIControlStateNormal];
}

#pragma mark - Game interaction

- (void)boardButtonTapped:(id)sender
{
    if (![sender isKindOfClass:[UIButton class]]) {
        NSAssert(0, @"Unexpected sender");
        return;
    }
    
    UIButton *button = sender;
    NSUInteger row = button.tag / kColCount;
    NSUInteger col = button.tag % kColCount;
    
    if ([self.game playerOccupyingRow:row col:col]) {
        return;
    }
    
    [self.game playSquareOnRow:row col:col];
    [self refreshSquareAtRow:row col:col];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != kObservationContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    if (object != self.game) {
        return;
    }
    
    if ([keyPath isEqualToString:@"currentPlayer"]) {
        //TODO
    }
    else if ([keyPath isEqualToString:@"isGameOver"]) {
        if (!self.game.isGameOver) {
            return;
        }
        
        NSString *title = NSLocalizedString(@"Game Over", nil);
        NSString *message = ^NSString *() {
            switch (self.game.winner) {
                case T3PlayerNone:
                    return NSLocalizedString(@"The game ended in a draw", nil);
                case T3PlayerX:
                    return NSLocalizedString(@"Player X is the winner!", nil);
                case T3PlayerO:
                    return NSLocalizedString(@"Player O is the winner!", nil);
            }
        }();
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"New Game", nil), nil];
        [alertView show];
    }
}

#pragma mark - Alert View Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // The only way this can be called is if the user tapped the "New Game" button in an alert view.
    [self.game resetGame];
    [self refreshBoard];
}

@end
