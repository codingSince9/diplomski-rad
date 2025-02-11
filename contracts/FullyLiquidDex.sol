// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.17;

import "./ERC20/Link.sol";
import "./ERC20/Matic.sol";
import "./ERC20/Sushi.sol";
import "./ERC20/Usdc.sol";
import "./ERC20/Wbtc.sol";

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FullyLiquidDecentralizedExchange {
    string public name = "Fully Liquid Decentralized Exchange";
    IERC20 public link;
    IERC20 public matic;
    IERC20 public sushi;
    IERC20 public usdc;
    IERC20 public wbtc;

    address public owner;
    mapping(address => mapping(address => uint256)) public reserves;
    // mapping for supported tokens
    mapping(address => bool) public supportedTokens;

    event TokenSwap(
        address indexed tokenSold,
        address indexed tokenBought,
        uint256 amountSold,
        uint256 amountBought
    );

    constructor(
        address _link,
        address _matic,
        address _sushi,
        address _usdc,
        address _wbtc
    ) {
        owner = msg.sender;
        supportedTokens[address(this)] = true;
        supportedTokens[address(_link)] = true;
        supportedTokens[address(_matic)] = true;
        supportedTokens[address(_sushi)] = true;
        supportedTokens[address(_usdc)] = true;
        supportedTokens[address(_wbtc)] = true;

        link = IERC20(_link);
        matic = IERC20(_matic);
        sushi = IERC20(_sushi);
        usdc = IERC20(_usdc);
        wbtc = IERC20(_wbtc);

        // x * y = k
        reserves[address(this)][address(usdc)] = 97000000000000000000000;
        reserves[address(usdc)][address(this)] = 170000000000000000000000000;
        // x (eth) = 97 000
        // y (usdc) = 170 000 000
        // k (constant product) = 164 900 000 000
        // price per ETH = 1750

        reserves[address(link)][address(usdc)] = 700000000000000000000000;
        reserves[address(usdc)][address(link)] = 5000000000000000000000000;
        // price per LINK = 7,14

        reserves[address(matic)][address(usdc)] = 900000000000000000000000;
        reserves[address(usdc)][address(matic)] = 1000000000000000000000000;
        // price per MATIC = 1,11

        reserves[address(sushi)][address(usdc)] = 950000000000000000000000;
        reserves[address(usdc)][address(sushi)] = 1000000000000000000000000;
        // price per SUSHI = 1,15

        reserves[address(wbtc)][address(usdc)] = 3550000000000000000000;
        reserves[address(usdc)][address(wbtc)] = 100000000000000000000000000;
        // price per WBTC = 28 170
    }

    function getAmountOut(
        address tokenSold,
        address tokenBought,
        uint256 amountSold
    ) public view returns (uint256) {
        require(
            supportedTokens[tokenSold] && supportedTokens[tokenBought],
            "Invalid token pair"
        );
        require(
            reserves[tokenSold][tokenBought] > 0 &&
                reserves[tokenBought][tokenSold] > 0,
            "Not enough liquidity in the pool"
        );
        // [ETH][DAI] = 9 700
        // [DAI][ETH] = 17 000 000
        uint256 numerator = reserves[tokenBought][tokenSold] * amountSold;
        uint256 denominator = reserves[tokenSold][tokenBought] + amountSold;
        return numerator / denominator;
    }

    function executeArbitrage(
        address tokenSold,
        address tokenBought,
        uint256 newReserve0Amount,
        uint256 newReserve1Amount
    ) public {
        require(
            supportedTokens[tokenSold] && supportedTokens[tokenBought],
            "Invalid token pair"
        );

        reserves[tokenSold][tokenBought] = newReserve0Amount;
        reserves[tokenBought][tokenSold] = newReserve1Amount;
    }

    function swap(
        address tokenSold,
        address tokenBought,
        uint256 _amountSold
    ) public payable {
        require(
            supportedTokens[tokenSold] && supportedTokens[tokenBought],
            "Invalid token pair"
        );
        // uint256 amountSold = msg.value;
        uint256 amountSold = _amountSold;
        uint256 amountBought = getAmountOut(tokenSold, tokenBought, amountSold);
        require(amountBought > 0, "Not enough liquidity in the pool");

        if (tokenBought == address(this)) {
            require(
                IERC20(tokenSold).transferFrom(
                    msg.sender,
                    address(this),
                    amountSold
                ),
                "Token transfer failed"
            );
            payable(msg.sender).transfer(amountBought);
        } else if (tokenSold == address(this)) {
            require(
                IERC20(tokenBought).transfer(msg.sender, amountBought),
                "Token transfer failed"
            );
        } else {
            require(
                IERC20(tokenSold).transferFrom(
                    msg.sender,
                    address(this),
                    amountSold
                ),
                "Token transfer failed"
            );
            require(
                IERC20(tokenBought).approve(msg.sender, amountBought),
                "Token transfer failed"
            );
        }
        reserves[tokenSold][tokenBought] += amountSold;
        reserves[tokenBought][tokenSold] -= amountBought;
        emit TokenSwap(tokenSold, tokenBought, amountSold, amountBought);
    }
}
