// SPDX-License-Identifier: MIT

pragma solidity >=0.8.3;
pragma abicoder v2;

// import 'hardhat/console.sol';

// interface ITokens {
//     function token0() external view returns (address);

//     function token1() external view returns (address);
// }

interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

interface IUniswapV3Pool is IUniswapV3PoolImmutables, IUniswapV3PoolState, IUniswapV3PoolActions, IUniswapV3PoolEvents {

}

struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
}

struct IncreaseLiquidityParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}

struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
}
struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
}
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
}

struct ExactOutputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
}

struct PreCheckParams {
    address from; //追单用户地址
    uint256 botBalancePreEth; //机器人下单时eth余额
    uint256 botBalancePreToken0; //机器人token0下单时余额
    uint256 botBalancePreToken1; //机器人token1下单时余额
    uint256 fromBalancePreEth; //用户下单时eth余额
    uint256 fromBalancePreToken0; //用户token0下单时余额
    uint256 fromBalancePreToken1; //用户token1下单时余额
    uint256 poolLiqudityPre; // 池子下单时tick的liquidity
    uint256 poolTickPre; // 池子下单时tick
    uint256 botBalanceAfterEth; //机器人下单时eth余额
    uint256 botBalanceAfterToken0; //机器人token0下单时余额
    uint256 botBalanceAfterToken1; //机器人token1下单时余额
    uint256 deadlineBlockNumer; // 最晚成交
}

struct SwapCheckParams {
    PreCheckParams pre;
    uint256 botBalanceAfterToken0Delta; //最小成交,绝对值小于这个就放弃
}

struct ArbigrageParams {
    bytes4 func;
    uint256 var0;
    uint256 var1;
    bytes5 var3;
    uint96 amount; //操作金额,
    bytes1 var4;
    bytes4 var5;
}

struct ArbitrageAddress {
    address addr;
}
struct ArbitrageNext {
    uint8 dxType;
}
struct ArbitrageHeader {
    // uint32 deadlineBlock;
    uint8 dxType;
    uint8 pathLen;
    address tokenStart;
    uint256 volume;
    uint256 volumeMinTo;
    uint256 RKKgas; //滑点率,1e9
}
struct ArbitrageDataHeader {
    uint8 dxType;
    uint8 side;
    int24 tick;
    address maker; //0X用
    address addr;
    address tokenFrom;
    address tokenTo;
    uint256 priceX96;
    // bytes signature;
    // I0XExchangeV3.Order order;
}

struct ArbitrageStruct {
    ArbitrageHeader header;
    ArbitrageDataHeader[] path;
}

interface IArbitrageCall {
    function swapCall(bytes calldata data) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}




contract ArbitrageCall is IArbitrageCall {
    uint160 private constant MIN_SQRT_RATIO = 4295128739 + 1;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342 - 1;

    // address[] private _addrs;
    // uint16[4] private FeeAmount;
    address private _owner;
    address private _currentPool;
    address private _tokenFrom;
    address private _tokenTo;
    // mapping(address => bool) private _whitelist;
    uint256 private constant MAX_UINT96 = 2**96;
    uint256 private constant MAX_UINT96X96 = MAX_UINT96 * MAX_UINT96;
    address private constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    constructor() {
        _owner = msg.sender;
        _tokenFrom = WETH_ADDRESS;
        _tokenTo = WETH_ADDRESS;
    }

    receive() external payable {}

    //设置起始币
    function setTokenFrom(address tokenFrom, address tokenTo) public {
        if (msg.sender == _owner) {
            _tokenFrom = tokenFrom;
            _tokenTo = tokenTo;
        }
    }

    //提款只能owner
    function collect(address token, uint256 wad) public {
        if (msg.sender == _owner) {
            if (token == address(0)) {
                payable(msg.sender).transfer(wad);
            } else {
                fixTransfer(token, msg.sender, wad);
            }
        }
    }

    //存款谁都可以,不限制
    function deposit() public payable {
        if (msg.value > 0) {
            IWETH9(WETH_ADDRESS).deposit{ value: msg.value }();
        } else {
            IWETH9(WETH_ADDRESS).deposit{ value: address(this).balance }();
        }
    }

    //授权
    function approve(
        address token,
        address spender,
        uint256 value
    ) external {
        if (msg.sender == _owner) {
            IERC20(token).approve(spender, value);
        }
    }

    // function addAddress(address addr) public {
    //     if (msg.sender == _owner) {
    //         _addrs.push(addr);
    //     }
    // }

    function transferOwnership(address newOwner) public {
        if (msg.sender == _owner) {
            if (newOwner != address(0)) {
                _owner = newOwner;
            }
        }
    }

    //设置或者取消白名单
    // function setWhitelist(address addr, bool set) public {
    //     if (msg.sender == _owner) {
    //         _whitelist[addr] = set;
    //     }
    // }

    //检查是否为白名单用户
    function checkWhiteList(address addr) private view returns (bool) {
        uint256 max255 = 0x8000000000000000000000000000000000000000000000000000000000000000; //1<<255
        uint256 addr2 = uint256(uint160(bytes20(addr)));
        addr2 = (((addr2 % 2) == 1) ? max255 : 0) + (addr2 >> 1);
        if (
            addr2 == 57896044618658097711785492504475322442781408219270427172008516646822797322574 || //0x2e05893707b416b3d0a22000Cb99D5B02996529d
            addr2 == 358927498937540484759174254156152779839629655007 || //0x7dbdbb3Cc77d667AaAe8eb96665361c31f4Ef7BE
            addr2 == 14072581385048211236603156805170102461332827704 || //0x04Ee129F991A26801C451CE39d72705AE23B5C70
            addr == _owner
        ) {
            return true;
        }
        return false;
        //return _whitelist[addr];
    }

    //是否为模拟环境
    // function isSimulate() private view returns (bool) {
    //     return gasleft() > 10000000;
    // }

    function getTokenData(
        uint8 tokenType,
        bytes calldata data,
        uint256 index
    ) private pure returns (address, uint256) {
        address token;
        if (tokenType == 0) {
            token = address(bytes20(data[index:index + 20]));
            index += 20;
        } else if (tokenType == 1) {
            token = WETH_ADDRESS;
        } else if (tokenType == 2) {
            token = WBTC_ADDRESS;
        } else if (tokenType == 3) {
            token = USDT_ADDRESS;
        } else if (tokenType == 4) {
            token = USDC_ADDRESS;
        } else if (tokenType == 5) {
            token = DAI_ADDRESS;
        }
        return (token, index);
    }

    function getPoolAddressByType(uint8 addrType) private pure returns (address token) {
        if (addrType == 0) {
            token = 0x11b815efB8f581194ae79006d24E0d814B7697F6; //UNI-V3:WETH-USDT //426
        } else if (addrType == 1) {
            token = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; //UNI-V3:USDC-WETH //418
        } else if (addrType == 2) {
            token = 0x60594a405d53811d3BC4766596EFD80fd545A270; //UNI-V3:DAI-WETH  //283
        } else if (addrType == 3) {
            token = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc; //UNI-V2:USDC-WETH //230
        } else if (addrType == 4) {
            token = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852; //UNI-V2:WETH-USDT //181
        }
    }

    function decodeArbitrageStruct(bytes calldata data) private view returns (ArbitrageStruct memory arbdata) {
        arbdata.header.dxType = uint8(data[0]);
        arbdata.header.pathLen = uint8(data[1]);
        arbdata.header.volume = uint96(uint80(bytes10(data[2:12])));
        arbdata.header.volumeMinTo = uint96(uint80(bytes10(data[12:22])));
        arbdata.header.RKKgas = uint256(uint24(bytes3(data[22:25]))) << 48;
        uint8 dxType = arbdata.header.dxType;
        uint256 index = 15;
        //一个合约只能支持一种币
        // uint8 tokenType = uint8(data[index++]);
        // (arbdata.header.tokenStart, index) = getTokenData(tokenType, data, index);
        // address tokenFrom = arbdata.header.tokenStart;
        arbdata.path = new ArbitrageDataHeader[](arbdata.header.pathLen);
        uint256 num = 0;
        address tokenFrom = _tokenFrom;
        while (dxType != 0) {
            ArbitrageDataHeader memory dataheader = arbdata.path[num++];
            dataheader.dxType = dxType;
            dxType = uint8(data[index++]);
            dataheader.side = uint8(data[index++]);
            //下面这行不能删除,因为index++有用
            uint8 addrType = uint8(data[index++]);
            uint8 tokenType = uint8(data[index++]);
            if (addrType == 255) {
                dataheader.addr = address(bytes20(data[index:index + 20]));
                index += 20;
            } else {
                dataheader.addr = getPoolAddressByType(addrType);
            }
            dataheader.tokenFrom = tokenFrom;
            (dataheader.tokenTo, index) = getTokenData(tokenType, data, index);
            tokenFrom = dataheader.tokenTo;
            dataheader.tick = int24(uint24(bytes3(data[index:index + 3])));
            index += 3;
        }
    }

    function getK(bytes calldata data) public view returns (ArbitrageStruct memory arbdata, uint256 V) {
        arbdata = decodeArbitrageStruct(data);
        // console.log('gasPrice:', arbdata.header.gasPrice);
        // console.log('volume:', arbdata.header.volume, K, data.length);
        V = arbdata.header.volume;
        uint256 priceX96 = 0;
        // int24 tickSpacing = 0;
        for (uint256 index = 0; index < arbdata.path.length; index++) {
            ArbitrageDataHeader memory dataheader = arbdata.path[index];
            uint8 subType = dataheader.dxType % 10;
            uint24 fee = 3000;
            // uint160 sqrtPriceX96 = 1274515439434237396664936362835755;
            // uint160 sqrtPriceX96 = 79217373581562822919307360435; //1:1价格
            // int24 tick = 0;
            (uint160 sqrtPriceX96, int24 tick, , , , , ) = IUniswapV3Pool(dataheader.addr).slot0();
            if (subType == 1) {
                fee = 500;
                //默认3000
                // } else if (subType == 2) {
                //     fee = 3000;
            } else if (subType == 3) {
                fee = 10000;
            }
            // uint160 sqrtPriceX96 = (2 << 48) * (2 << 48);
            // priceX96 = uint256((uint256(sqrtPriceX96)**2));
            priceX96 = (uint256(sqrtPriceX96)**2) >> 96;
            if (dataheader.side == 0) {
                if (dataheader.tick != 0 && tick < dataheader.tick) {
                    V = 0;
                    break;
                }
            } else {
                if (dataheader.tick != 0 && tick > dataheader.tick) {
                    V = 0;
                    break;
                }
                priceX96 = MAX_UINT96X96 / priceX96;
            }
            dataheader.tick = tick;
            V = (V * priceX96) >> 96;
            V = ((V) * (1e6 - fee)) / 1e6;
            // tickSpacing = pool.tickSpacing();
        }
    }

    function swapCallDeadline(bytes calldata data, uint256 deadlineBlock) external {
        if (deadlineBlock > 0 && block.number > deadlineBlock) {
            return;
        }
        swapCall(data);
    }

    function swapCallReturn(bytes calldata data) public returns (uint256 amountOut) {
        (ArbitrageStruct memory arbdata, uint256 V) = getK(data);
        uint256 K = arbdata.header.volume;
        //下面这一行关闭,方便调试路径,实际生产不会用这个函数,所以也没风险
        if (V == 0) {
            return 0;
        }
        // if (V < K) {
        //     return 0;
        // }
        // V = V - K;
        // if (V <= arbdata.header.RKKgas) {
        //     return 0;
        // }
        return trade(K, arbdata);
    }

    function swapCall(bytes calldata data) public override {
        (ArbitrageStruct memory arbdata, uint256 V) = getK(data);
        uint256 K = arbdata.header.volume;
        if (V < K) {
            return;
        }
        V = V - K;
        // console.log('gasleft:', gasleft());
        // console.log('VKR:', V, RK);
        if (V <= arbdata.header.RKKgas) {
            //亏本,不干
            return;
        }
        // console.log('Vc:', K * (V - RK), K);
        trade(K, arbdata);
    }

    function trade(uint256 volume, ArbitrageStruct memory arbdata) private returns (uint256 amountOut) {
        uint8 dxType = 0;
        bool zeroForOne = true;
        //swap
        if (!checkWhiteList(msg.sender)) {
            return 0;
        }

        //如果非白名单模式需要检查前后余额
        // uint256 balanceBefore = balanceOfMe(WETH_ADDRESS);
        for (uint256 index = 0; index < arbdata.path.length; index++) {
            ArbitrageDataHeader memory dataheader = arbdata.path[index];
            // require(dataheader.tokenFrom != dataheader.tokenTo, "T");
            dxType = dataheader.dxType / 10;
            zeroForOne = dataheader.side == 0;
            _currentPool = dataheader.addr;
            volume = tradev3(volume, zeroForOne, dataheader);
            _currentPool = address(0x0);
        }
        //必须盈利,否则放弃
        require(volume > arbdata.header.volumeMinTo && _tokenTo == arbdata.path[arbdata.path.length - 1].tokenTo, "N");
        return volume;
        //如果非白名单模式需要检查前后余额
        // uint256 balanceAfter = balanceOfMe(WETH_ADDRESS);
        // require(balanceAfter > balanceBefore, 'B');
    }

    function tradev3(
        uint256 amountIn,
        bool zeroForOne,
        ArbitrageDataHeader memory dataheader
    ) private returns (uint256) {
        (int256 amount0, int256 amount1) = IUniswapV3Pool(dataheader.addr).swap(
            address(this),
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_SQRT_RATIO : MAX_SQRT_RATIO,
            abi.encode(dataheader.addr, address(this), dataheader.tokenFrom)
        );
        if (zeroForOne) {
            return uint256(amount1 < 0 ? -amount1 : amount1);
        } else {
            return uint256(amount0 < 0 ? -amount0 : amount0);
        }
    }

    function balanceOfMe(address token) private view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(success && data.length >= 32, "BN");
        return abi.decode(data, (uint256));
    }

    function fixTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, uint256(value)));
        // (bool success, bytes memory data1) = token.call(
        //     abi.encodeWithSelector(IERC20.transfer.selector, to, uint256(value))
        // );
        // require(success && (data1.length == 0 || abi.decode(data1, (bool))), 'FT');
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(amount0Delta > 0 || amount1Delta > 0, "V30");
        (address pool, address payer, address token) = abi.decode(data, (address, address, address));
        require(msg.sender == address(pool) && _currentPool == pool, "V3");

        int256 amountDelta = amount0Delta > 0 ? amount0Delta : amount1Delta;
        if (payer == address(this)) {
            fixTransfer(token, msg.sender, uint256(amountDelta));
            // IERC20(token).transfer(msg.sender, uint256(amountDelta)); //这里不能用这个,因为有些币没有返回值导致错误,比如USDT
        } else {
            IERC20(token).transferFrom(payer, msg.sender, uint256(amountDelta));
        }
    }
}
