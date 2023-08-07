// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {GasSnapshot} from "../../lib/forge-gas-snapshot/src/GasSnapshot.sol";
import {TickBitmap} from "../../contracts/libraries/TickBitmap.sol";

contract TickBitmapTestTest is Test, GasSnapshot {
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public bitmap;

    function isInitialized(int24 tick) internal view returns (bool) {
        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(tick, 1, true);
        return next == tick ? initialized : false;
    }

    function flipTick(int24 tick) internal {
        bitmap.flipTick(tick, 1);
    }

    function test_isInitialized_isFalseAtFirst() public {
        assertEq(isInitialized(1), false);
    }

    function test_isInitialized_isFlippedByFlipTick() public {
        flipTick(1);

        assertEq(isInitialized(1), true);
    }

    function test_isInitialized_isFlippedBackByFlipTick() public {
        flipTick(1);
        flipTick(1);

        assertEq(isInitialized(1), false);
    }

    function test_isInitialized_isNotChangedByAnotherFlipToADifferentTick() public {
        flipTick(2);

        assertEq(isInitialized(1), false);
    }

    function test_isInitialized_isNotChangedByAnotherFlipToADifferentTickOnAnotherWord() public {
        flipTick(1 + 256);

        assertEq(isInitialized(257), true);
        assertEq(isInitialized(1), false);
    }

    function test_flipTick_flipsOnlyTheSpecifiedTick() public {
        flipTick(-230);

        assertEq(isInitialized(-230), true);
        assertEq(isInitialized(-231), false);
        assertEq(isInitialized(-229), false);
        assertEq(isInitialized(-230 + 256), false);
        assertEq(isInitialized(-230 - 256), false);

        flipTick(-230);
        assertEq(isInitialized(-230), false);
        assertEq(isInitialized(-231), false);
        assertEq(isInitialized(-229), false);
        assertEq(isInitialized(-230 + 256), false);
        assertEq(isInitialized(-230 - 256), false);

        assertEq(isInitialized(1), false);
    }

    function test_flipTick_revertsOnlyItself() public {
        flipTick(-230);
        flipTick(-259);
        flipTick(-229);
        flipTick(500);
        flipTick(-259);
        flipTick(-229);
        flipTick(-259);

        assertEq(isInitialized(-259), true);
        assertEq(isInitialized(-229), false);
    }

    function test_flipTick_gasCostOfFlippingFirstTickInWordToInitialized() public {
        snapStart("flipTick_gasCostOfFlippingFirstTickInWordToInitialized");
        flipTick(1);
        snapEnd();
    }

    function test_flipTick_gasCostOfFlippingSecondTickInWordToInitialized() public {
        flipTick(0);

        snapStart("flipTick_gasCostOfFlippingSecondTickInWordToInitialized");
        flipTick(1);
        snapEnd();
    }

    function test_flipTick_gasCostOfFlippingATickThatResultsInDeletingAWord() public {
        flipTick(0);

        snapStart("flipTick_gasCostOfFlippingATickThatResultsInDeletingAWord");
        flipTick(0);
        snapEnd();
    }

    function setUpSomeTicks() internal {
        int24[9] memory ticks = [int24(-200), -55, -4, 70, 78, 84, 139, 240, 535];

        for (uint256 i; i < ticks.length - 1; i++) {
            flipTick(ticks[i]);
        }
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTickToRightIfAtInitializedTick() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(78, 1, false);

        assertEq(next, 84);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTickToRightIfAtInitializedTick2() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(-55, 1, false);

        assertEq(next, -4);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTheTickDirectlyToTheRight() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(77, 1, false);

        assertEq(next, 78);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTheTickDirectlyToTheRight2() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(-56, 1, false);

        assertEq(next, -55);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTheNextWordsInitializedTickIfOnTheRightBoundary()
        public
    {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(255, 1, false);

        assertEq(next, 511);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTheNextWordsInitializedTickIfOnTheRightBoundary2()
        public
    {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(-257, 1, false);

        assertEq(next, -200);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_returnsTheNextInitializedTickFromTheNextWord() public {
        setUpSomeTicks();
        flipTick(340);

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(328, 1, false);

        assertEq(next, 340);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_doesNotExceedBoundary() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(508, 1, false);

        assertEq(next, 511);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_skipsEntireWord() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(255, 1, false);

        assertEq(next, 511);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_skipsHalfWord() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(383, 1, false);

        assertEq(next, 511);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_gasCostOnBoundary() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteFalse_gasCostOnBoundary");
        bitmap.nextInitializedTickWithinOneWord(255, 1, false);
        snapEnd();
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_gasCostJustBelowBoundary() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteFalse_gasCostJustBelowBoundary");
        bitmap.nextInitializedTickWithinOneWord(254, 1, false);
        snapEnd();
    }

    function test_nextInitializedTickWithinOneWord_lteFalse_gasCostForEntireWord() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteFalse_gasCostForEntireWord");
        bitmap.nextInitializedTickWithinOneWord(768, 1, false);
        snapEnd();
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_returnsSameTickIfInitialized() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(78, 1, true);

        assertEq(next, 78);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_returnsTickDirectlyToTheLeftOfInputTickIfNotInitialized()
        public
    {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(79, 1, true);

        assertEq(next, 78);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_willNotExceedTheWordBoundary() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(258, 1, true);

        assertEq(next, 256);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_atTheWordBoundary() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(256, 1, true);

        assertEq(next, 256);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_wordBoundaryLess1nextInitializedTickInNextWord() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(72, 1, true);

        assertEq(next, 70);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_wordBoundary() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(-257, 1, true);

        assertEq(next, -512);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_entireEmptyWord() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(1023, 1, true);

        assertEq(next, 768);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_halfwayThroughEmptyWord() public {
        setUpSomeTicks();

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(900, 1, true);

        assertEq(next, 768);
        assertEq(initialized, false);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_boundaryIsInitialized() public {
        setUpSomeTicks();
        flipTick(329);

        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(456, 1, true);

        assertEq(next, 329);
        assertEq(initialized, true);
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_gasCostOnBoundary() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteTrue_gasCostOnBoundary");
        bitmap.nextInitializedTickWithinOneWord(256, 1, true);
        snapEnd();
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_gasCostJustBelowBoundary() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteTrue_gasCostJustBelowBoundary");
        bitmap.nextInitializedTickWithinOneWord(255, 1, true);
        snapEnd();
    }

    function test_nextInitializedTickWithinOneWord_lteTrue_gasCostForEntireWord() public {
        setUpSomeTicks();

        snapStart("nextInitializedTickWithinOneWord_lteTrue_gasCostForEntireWord");
        bitmap.nextInitializedTickWithinOneWord(1024, 1, true);
        snapEnd();
    }
}