// SPDX-License-Identifier: MIT

pragma solidity >=0.8.3;
pragma abicoder v2;

import "./IUniswapV3Pool.sol";
import "./IArbitrageCall.sol";
import "./IERC20.sol";
import "./IWETH9.sol";

// import './console.sol';

// interface ITokens {
//     function token0() external view returns (address);

//     function token1() external view returns (address);
// }

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
