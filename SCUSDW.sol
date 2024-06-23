// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";


contract SCUSDWT is ERC20, ERC20Pausable {

    bytes32 public chainUid;//chain or DLTのUID、絶対座標ID。
    
    //owner
    //ownerの鍵は変更されない、ownerのPWDコードがハックされうる
    address payable private ownerKey;
    
    // modifier to check if caller is [pwd]user [pwd:pwd of pwdHash first auth aikotoba] 
    modifier isOwner() {
        require(ownerKey==msg.sender,"Caller is not owner");
        _;
    }

    //lToken
    IERC20 public lToken;

    
    constructor(
        address USD_stablecoin_lToken_Contract_Address
    )
    ERC20("ShinCoin USDWT", "SCUSDW")
    {
        kanban_this_contract=sha256(abi.encodePacked(
                                                        "[sample-code]",
                                                        "ERC20-USD-Stablecoin Wrapped by ShinCoin USDWT",
                                                        "With code auth.Pwd hash auth.Nance.User check/petitKYC",
                                                        "2024-06-23",
                                                        "For ShinCoin Sole project. and other StableCoin project."
                                                        "ShinCoin by SINGULION",
                                                        "code_by_Katsuya Nishizawa"
                                                    ));

        //rToken :set This rToken
        casalt = sha256(abi.encodePacked("lrToken_ERC20PWDH_sample_20420623"));
        blockTime=12;
        rate_pwdHash_Service_Value_In_rToken = 1;
        
        //ltoken :set interface
        lToken = IERC20(USD_stablecoin_lToken_Contract_Address);
        
        //rToken-lToken-RATE-RATIO
        lToken_Amount=10;
        rToken_Amount=1;
        
        //例：lToken:USDTの場合、USDT10個を包んでrToken_Amount=1とする場合。
        //問題なければUSDT=1個を本件rToken1で包んで提供。
        //rTokenはパスワード機能のついた手提げ金庫入りのUSDなSCを想定。

        //owner :set owber EOA and Pwdhash
        ownerKey=payable(msg.sender);
        //ownerのrToken送金限度額設定PWDHASHしておくこと。
        //以下はパスワード.solに打ち込み式だが、実際はハッシュ値そのものをコンストラクタで打つこと。
        //なおowner-pwdhashは送金の知財特権で設定するとする。ライセンスによるトークン割り当てfee不要とする。
        //ShinCoinではパスワードハッシュ部手数料をIP所持者に送金。
        bytes32 newPwdHash_owner_1st = sha256(abi.encodePacked(
                  "Actually, type the hash value itself in the constructor.___ioancccg75__7245936_rToken_r4837t"
                ));

        _mint(ownerKey, rate_pwdHash_Service_Value_In_rToken);//初回pwdhash-setの為１M発行（次の１Mで合計２M）
        

        //use rToken ,set PwdHash (1-rToken used)
        s_pwdHash_Service_And_Pay_rToken_ByUser(ownerKey,rate_pwdHash_Service_Value_In_rToken, newPwdHash_owner_1st,"initial nowPwdHash is 0x0");
        
        require(userToPwdHash[ownerKey]==newPwdHash_owner_1st,"err");//パスワードセットOKか。

        //initial lToken-rToken lock mining FD stake (test)
        
            //lid初期化、test_lid-0
            lidCnt=0;
            mining_PartsPerMillion_With_365Bn=5.36*10**4;//今の米国債365金利反映、US1Y、デモ用。預金も1年以内しかつかない。
            uint initial_lid_amount=10**6;//

            //lid-Bnのリスト
            lid_To_Locked_Bn[lidCnt]=block.number;

            //lid-mining-percent (なお、このパーセントはlidとEOAに連動し、他のEOAには譲渡できない。EOA口座に金利つく）
            lid_To_Locked_Mining_Percent[lidCnt]=mining_PartsPerMillion_With_365Bn;

            //ロック量帳簿インクリメント
            lid_To_rToken_Amount[lidCnt]=initial_lid_amount; 
            
            //initial rToken mint
            _mint(ownerKey, initial_lid_amount);
            //ID=0のオーナー分無くして手数料だけのモデルも有り。ただここはミント。これを見てたくさん入れないよね的な。やや威嚇。
    
    }

    //ポーズはPwdいる。AML用。
    function pause(string memory nowPwd) 
    public 
    isOwner
    isPwdHashUser(nowPwd)
    {
        _pause();
    }

    //アンポーズ。Pwdもクラックされるとコントラクト完全に停止する。
    function unpause(string memory nowPwd) 
    public 
    isOwner
    isPwdHashUser(nowPwd)
    {
        _unpause();
    }


//ERC20PWDH、送付アップデート部=====================================================================
    // The following functions are overrides required by Solidity.
    //知識パスワード認証で設定された送付限度額を超えての送付行わない機能を持つ転送部
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {   
        /*
            //ERC20LT
            //参考：口座制限モード設定。AML 実施にはEOAのデータベースが必要のため通常実装しにくい。Pause関数でAML対処か。
            require( g_userToTxLimitedAmount(from) >= value , "err:tx is limited userToTxLimitedAmount_ByOwner");
        */

        //ERC20PWDH=========
            //口座開設的なPwdHash設定しないとRxできなくて受取はできない。
            //lTokenをロックし、ltokenを所定量消費して口座設定・パスワードハッシュ設定しないと口座動かない。
        
        //TX部
        //tx Limit by user PwdHash
        require(userToTxLimitFlag_ByUser[from] == false, "err:tx is limited[true] by Tx user[EOA:from]_if transfermode please change flag[false]");
        require(value >= userToTxLimitAmount_ByUser[from] , "err:tx is limited by Tx user[EOA:from]_if transfermode please change Amount.");

        /*
            //参考RX部
            //Rx Limit or unlock by user PwdHash
            require(value >= userToRxLimitAmount_ByUser[to] , "err:rx is limited by Rx user[EOA:to]_if transfermode please change Amount.");
        */

        //送付実行、update
        super._update(from, to, value);
    }


    /*
        //参考：口座制限モード設定。AML
        //address of limited-List(AML)
        mapping(address => uint256)public userToTxLimitedAmount_ByOwner; //Tx制限
        function s_userToTxLimitedAmount_ByOwner(address user_limited, uint256 value_max_tx,string memory nowPwd)    
        public 
        isOwner
        isPwdHashUser(nowPwd)
        {
            userToTxLimitedAmount_ByOwner[user_limited]=value_max_tx;
        }
        //口座制限モード読取。ノーマリーオフにするため逆変換、2^256-1-[userToLimitedAmount_ByOwner]にする。
        function g_userToTxLimitedAmount(address user_limited)    
        public view
        returns (uint)
        {
            return ( (2**256-1) - userToTxLimitedAmount_ByOwner[user_limited] );
        }
    */

//==============================================
//ERC20PWDHユーザからの送金限度額設定部=====================================================================
//ガスが必要。PwdHash設定しないと使えない＝IP feeないと使えない。


    //1TXあたりの送金Tx限度部、ユーザ定義
    mapping(address => bool) private userToTxLimitFlag_ByUser;//ノーマリーアンロック
    mapping(address => uint256) private userToTxLimitAmount_ByUser;//ノーマリーロック（パスワードハッシュ設定必須＝サービス支払い必須）


    //TX許可・禁止フラグ設定関数
    function s_txLimitFlag_ByUser_PwdHash(bool lockState_EG_true_Is_Lock , string memory nowPwd)
    isPwdHashUser(nowPwd)
    public
    {
        //送金額制限
        userToTxLimitFlag_ByUser[msg.sender]=lockState_EG_true_Is_Lock;//0から2**256-1
    }    

    //TX転送設定関数
    //あらかじめパス無しでEOAにチャージしておいてパスワードをEOA送付された人が設定するとパスコードマネーになる。
    function s_txLimitAmount_ByUser_PwdHash(uint256 newMaxAmount , string memory nowPwd)
    isPwdHashUser(nowPwd)
    public
    {
        //送金額制限
        userToTxLimitAmount_ByUser[msg.sender]=newMaxAmount;//0から2**256-1
    }    

    /*
    //参考RX部
    //ただし、パブリックキーをTXで初回DLTに転送時にパブリックキー読み取り＋パブリックキーから秘密鍵算出攻撃の防御の視点で、以下RX入れない。
        //1RXあたり限度部、ユーザ定義
        mapping(address => uint256) private userToRxLimitAmount_ByUser;//ノーマリーロック（パスワードハッシュ設定必須＝サービス支払い必須）

        //RX転送設定関数
        function s_rxLimitAmount_ByUser_PwdHash(uint256 newMaxAmount , string memory nowPwd)
        isPwdHashUser(nowPwd)
        public
        {
            //受取額制限
            userToRxLimitAmount_ByUser[msg.sender]=newMaxAmount;//0から2**256-1
            //Rxはいらない場合もある。
        }
    */



//知識型パスワード設定部(役務提供部)=====================================================================
//注意：パスワードのメッセージデータ忘れると送金できない


    //ユーザ毎のPwdハッシュ
    //アクセス用データ記録型PKI秘密鍵に加えて知識所有パスワードメッセージ式秘密キー。
    mapping(address => bytes32) private userToPwdHash;

    //第1pwd部：isPwdHashUser、
    //pwdハッシュ直接記録型認証部
    uint256 rate_pwdHash_Service_Value_In_rToken;
    function s_rate_pwdHash_Service_Value_In_rToken(uint256 newRate,string memory nowPwd)
    public
    isOwner
    isPwdHashUser(nowPwd)
    noReentrancy//Just in case, prevent re-entry when using internal currency 
    {
        rate_pwdHash_Service_Value_In_rToken=newRate;
    }


    //パスワードハッシュのユーザによる書き込み(saltなし) Log byte data
    function s_pwdHash_Service_And_Pay_rToken_ByUser(
        address pay_user,
        uint256 user_PayFeeAmount_BurnUsers_MintOwners, 
        bytes32 newPwdHash,string memory nowPwd
    )
    public
    isPwdHashUser(nowPwd)
    noReentrancy//Just in case, prevent re-entry when using internal currency 
    returns (address recept_paid_user,bytes32 recept_newPwdHash, uint256 recept_fee_Paid_Amount_rToken)
    {
        require(msg.sender == pay_user);
        require(rate_pwdHash_Service_Value_In_rToken==user_PayFeeAmount_BurnUsers_MintOwners,"service fee amount different");

        if(userToPwdHash[msg.sender]==0x0){
            //パスワード未定義、初期ゼロの時、
            userToPwdHash[msg.sender] = newPwdHash;

        }else {
            require(userToPwdHash[msg.sender]==sha256(abi.encodePacked(nowPwd)),"err:pwd-hash different");

            //noReentrancy
            //役務提供、イメージとしては手提げ金庫入りイーサの金庫のダイヤルを設定し送金限設定可能に
            userToPwdHash[msg.sender] = newPwdHash;
            
                _burn(msg.sender,user_PayFeeAmount_BurnUsers_MintOwners);
                _mint(ownerKey,user_PayFeeAmount_BurnUsers_MintOwners); 
                return (msg.sender,userToPwdHash[msg.sender] ,user_PayFeeAmount_BurnUsers_MintOwners) ;
        }
    }

    //パスワードハッシュのユーザによる確認
    function g_PwdHash_ByUser(string memory nowPwd)
    public view
    isPwdHashUser(nowPwd)
    returns (bytes32)
    {
        return userToPwdHash[msg.sender];
    }

    // modifier to check if caller is [pwd]user [pwd:pwd of pwdHash first auth aikotoba] 
    modifier isPwdHashUser(string memory nowPwd) {
        require(msg.sender!=address(0),"zero address");//zero address利用は想定なし
        
        if(userToPwdHash[msg.sender]==0x0){
            revert("err:logged pwd hash is 0x0");

        }else {
            require(userToPwdHash[msg.sender]==sha256(abi.encodePacked(nowPwd)),"err:pwd-hash different");
        }    
        _;
    }


//マイニング部PoS=====================================================================
    //コントラクトデプロイ時刻
    uint256 public contract_DeployedBn=block.number;
    
    //最新の取引値、ステークlidの有無
    uint256 public contract_lid_LatestBn_As_Activity=block.number;//活性度記録：なくてもよい。固定またはオーナー管理のmining率の場合

    uint256 public mining_PartsPerMillion_With_365Bn=50000;//uint8でもいいがより数表現しやすくするため増やした。
    //1 ppmは 0.0001 パーセント, 1000ppmは0.1% , 10000ppmは1%.
    
    //レートset。鉱脈を探すの巻。探すにはパスワードハッシュ設定必要に…
    //パスワードハッシュ設定は鉱脈探すコンパスでもあるのか。
    function s_Mining_Percent_ByOwner(string memory nowPwd)
    public
    isOwner
    isPwdHashUser(nowPwd)
    noReentrancy
    returns (uint256 newPercent)
    {        
        require(mining_PartsPerMillion_With_365Bn*2>newPercent,"err:1 operation is under twice");//一回のTX操作で増加可能なのは２倍％。徐々に利上げ、利下げは一瞬。
        mining_PartsPerMillion_With_365Bn = newPercent;
        return mining_PartsPerMillion_With_365Bn;
    }

//mint-Rent====================================
//pay-lock-lToken-mint-Rent-rToken

        //rToken-lToken-RATE-RATIO
        uint256 public lToken_Amount=10;//USDTなどのドル建てSC１つを1対1又は1対10で包んでラップして利用。
        uint256 public rToken_Amount=1;

        //get Lock_lToken_Ratio/Rent_rToken_Ratio
        function g_lToken_rToken_Ratio()
        public view
        returns (uint256)
        {
           return lToken_Amount/rToken_Amount;
        }


        //lid=lock-rent-id
        uint256 public lidCnt;//lidcnt
        //lrid-Bn
        mapping(uint256 => bool)
                public lid_To_Valid; //lrid-valid(及び再突入防止用）
        //lrid-Bn
        mapping(uint256 => address)
                public lid_To_User; //lrid-user
        //lid - user - lock amount
        mapping(uint256 => uint256)
                public lid_To_lToken_Amount; //lTokenのlridのリスト、EOA名義に金利またはマイニング率がついている
                //＊lidの異なるEOA間での譲渡は不可能とする。Cf：預貯金債権の譲渡禁止特約
        
        //lid - user - rent amount
        mapping(uint256 => uint256)
                public lid_To_rToken_Amount; //rTokenのlridのリスト
        
        //lrid-L-Bn
        mapping(uint256 => uint256)
                public lid_To_Locked_Bn; //lrid-Bnのリスト、デポジットしてmining用。

        //lrid-U-Bn
        mapping(uint256 => uint256)
                public lid_To_Unlocked_Bn; //lrid-Bnのリスト、返却時記録・再突入防止

        //lrid-mining-percent
        mapping(uint256 => uint256)
                public lid_To_Locked_Mining_Percent; //lid-ロック時金利のリスト

        //lrid-mining-Amount
        mapping(uint256 => uint256)
                public lid_To_Unlocked_Mining_Amount; //lid-アンロック時マイニング量/利息の記録
        /*
        //lrid-mining-period-day(1dayBn)
        mapping(uint256 => uint256)
                public lid_To_Locked_mining_day; //lid-ロック時金利の定期預金預け入れ日数は未実装。1年間短期PoS時
        */


        //ロック＆レント。 lTokenのロック量をクレジットスコアにしてrTokenをユーザはコントラクトから借りるのでレント。ポストペイド。
        //1年預けると1年はコントラクトからlTokenアンロックできない。マイニング利息は1年分を上限につく。シンプル1年ステーク
        //なおコントラクトオーナーはコントラクトからlTokenを外部に所定条件で移動できるとする
        //rTokenはlTokenのwrapped-token・ラップドトークン・包トークンである。
            //＊lidにEOAつけないときはlidは利子付き債券のID（NFTライク）になるが、今回は銀行口座、名義への定期預金を模倣しているのでEOA固定。
        function lock_lToken_365dayBn_And_Rent_rToken
        (address account, uint256 lock_lToken_Amount, uint256 rent_rToken_Amount) 
        public
        noReentrancy//Just in case, prevent re-entry when using internal currency
        returns(bool result,uint this_lid,uint rent_rToken_amount)
        {
            //CEI（Checks-Effects-Interactions）

            //Check
            
                //lr-ratio
                //Lock_lToken_Ratio/Rent_rToken_Ratio
                uint256 ratio = lock_lToken_Amount/rent_rToken_Amount;
                require(g_lToken_rToken_Ratio() == ratio,"input ratio");//入力量検証。もし違うとき関数入力誤りの為返す。
                
                //user-amount
                require(msg.sender==account);
                //もしユーザがlToken残高ないとき停止。
                require(lToken.balanceOf(msg.sender)>=lock_lToken_Amount,"lToken balance");
            

            //[noReentrancy is need]
            //Effects
            
                //lidインクリメント
                lidCnt++;
                uint lid=lidCnt;
                
                //lidにユーザを割り当て
                lid_To_User[lid]==msg.sender;//lid-user

                //lid有効にする　(及び再突入防止）
                lid_To_Valid[lid]=true;

                //lid-L-Bnのリスト
                lid_To_Locked_Bn[lid]=block.number;
            
            
            //Interactions
            
                //accept lock lToken
                //[Asset]log locked lToken
                //transfer(address recipient:受信者=このコントラクトaddress(this), uint256 amount) → bool
                require( lToken.transfer( address(this), lock_lToken_Amount) == true , "Transfer failed");
                //ロック量帳簿インクリメント
                lid_To_lToken_Amount[lid]=lid_To_lToken_Amount[lid]+lock_lToken_Amount;                 

                    //[Asset]rent mint rToken amout of[rent_rToken_Amount)]
                    _mint(msg.sender, rent_rToken_Amount);
                    //レント量帳簿インクリメント
                    lid_To_rToken_Amount[lid]=lid_To_rToken_Amount[lid]+rent_rToken_Amount;

                        //set lid-mining-percent (なお、このパーセントはlidとEOAに連動し、他のEOAには譲渡できない）
                        lid_To_Locked_Mining_Percent[lid]=mining_PartsPerMillion_With_365Bn/10000;
            

            //return : res,lid,rent-amount
            return (true,lidCnt,rent_rToken_Amount);
        }

        //リターン・アンロック。rTokenを返してlTokenを出す。
        function return_rToken_And_Unlock_lToken
        (uint256 lid, address account_unlocker, uint256 unlock_lToken_Amount_ThisLid,uint256 return_rToken_Amount_ThisLid) 
        public
        noReentrancy//Just in case, prevent re-entry when using internal currency
        returns(bool result,uint256 expired_lid,uint256 unlock_lToken)
        {
            //CEI（Checks-Effects-Interactions）
            
            //Check
            
                //利用日数
                uint256 lr_day=(block.number-lid_To_Locked_Bn[lid])/bnm_day;
                //期限未満償還は不可能
                require(lr_day < 1*365 , "not 365 day Bn spend.");
             
                //lr-ratio
                //Lock_lToken_Ratio/Return_rToken_Ratio
                uint256 ratio = unlock_lToken_Amount_ThisLid/return_rToken_Amount_ThisLid;
                require(g_lToken_rToken_Ratio() == ratio,"input ratio");//入力量検証。もし違うとき関数入力誤りの為返す。                   
                
                //rToken amount check 一括返済を要求、return量
                require(lid_To_rToken_Amount[lid]==return_rToken_Amount_ThisLid);
                //lToken amount check 一括返済を要求、return量
                require(lid_To_rToken_Amount[lid]==unlock_lToken_Amount_ThisLid);

                //user-amount
                require(msg.sender==account_unlocker);
                require(lid_To_User[lid]==msg.sender);//lid-user
                //もしユーザがrToken残高ないとき停止。
                require(balanceOf(msg.sender)>=return_rToken_Amount_ThisLid,"rToken balance");             
                    //考えにくいが、アンロック返送後u256以上の量はオーバーフローするので返さない？
                    require( lToken.balanceOf(msg.sender)+ lid_To_rToken_Amount[lid]> (2**256-1),"balance will over.lToken tx another EOA.");                
            
            
            //[noReentrancy is need]
            //Effects 実データのガス利用記録            
            
                //lid-U-Bnのリスト
                lid_To_Unlocked_Bn[lid]=block.number;
                
                //lidを無効にする。マイニングPoS終了済みの記録
                lid_To_Valid[lid]=false;
            
            
            //Interactions
            
                //rTokenのマイニング記録（条件によっては利息記録）
                //mining量の記録（利用開始時の利率とそれから現在までの期間反映。ただし端数切り下げ。）
                lid_To_Unlocked_Mining_Amount[lid]=check_Mining_Amount_If_Now_Unlocked(lid);
                //rTokenマイニングmint
                _mint(msg.sender, lid_To_Unlocked_Mining_Amount[lid]);

                //ロック解除
                    //rTokenのバーン
                    _burn(msg.sender, return_rToken_Amount_ThisLid);
                    lid_To_rToken_Amount[lid]=lid_To_rToken_Amount[lid]+return_rToken_Amount_ThisLid;

                    //[Asset]Return lToken 返却
                    //transfer(address recipient:受信者=to-User=msg.sender, uint256 amount) → bool                    
                    require(lToken.transfer(msg.sender, unlock_lToken_Amount_ThisLid) , "Transfer failed");

                    //ロック量帳簿減算(mining記録後に処理する！）
                    lid_To_rToken_Amount[lid]=lid_To_rToken_Amount[lid]-unlock_lToken_Amount_ThisLid; //lock-lrid
            
            return (true,lid,unlock_lToken_Amount_ThisLid);
        }

        //マイニング又は利息計算内部関数(mining PoS)、ロック元SCでなくレントのrTokenでつく利息
        //mining量をチェックする関数、
        function check_Mining_Amount_If_Now_Unlocked(uint256 lid) 
        public view       
        returns(uint mining_amount_if_now_unlocked)
        {            
            //利用日数
            uint256 lr_day=(block.number-lid_To_Locked_Bn[lid])/bnm_day;

            //利用日数が1年分を超えているとき、1年債的な感じの償還またはマイニング鉱脈堀つくしか。
            //定期預金は自動召喚されない。本機能は1年毎預入直ししないと預金金利つかなくなる。
            if(lr_day>1*365){//1年以上では1年分にする。定期預金期限後は再度おろしてもう一回オーナー指定の短期１年金利にして。（FRBの制御する金利参考）
                lr_day=1*365;
            }

            //利息計算式
            //利息＝ステーク残高（元金）×金利（年率）÷365日×返済日までの利用日数
            uint mining=lid_To_rToken_Amount[lid] * mining_PartsPerMillion_With_365Bn /10000 /100 /365* lr_day;

            return mining;
        }




////////////////////////////////////
    //noReentrancy
    bool public locked;
    modifier noReentrancy() {
        require(!locked, "No reentrancy");

        locked = true;
        _;
        locked = false;
    }
////////////////////////////////////



//TOTPモード部==================================================
uint blockTime=12;
uint bnm_minute=60/blockTime;
uint bnm_day=60*60*24/blockTime;
bytes32 private casalt;


//BnmTOTP　ベース部。//１ウィークなどのbnm数をinputしてuse。
    function totpHashCulc_Bnm(address eoa,uint256 bnm,uint256 tid,bytes32 b32)
    internal view 
    returns (bytes32)
    {
        require(eoa!=address(0),"zero address");
        require(bnm>0,"revert,bnm=0");
        return sha256( abi.encodePacked (eoa ,block.number/bnm , tid, balanceOf(msg.sender), b32,
                                            address(this), casalt) ) ;
    }

    //calc 12digit
    function culcTotp_Bnm(address eoa,uint256 bnm,uint256 tid,bytes32 b32)
    internal view 
    returns (uint256)
    {
        return uint256(totpHashCulc_Bnm(eoa,bnm,tid,b32)) % 10**12;//12乗12digitであればカジノ利用じゃなかろう。またcasaltがKcで変更されておらず決定的だから乱数ではない。多分。
    }


//具体的な用途向け関数群
//for userCheck,CR.deep-mode 12digit
    function callTotp_5bn_ByPwdHashUser(uint256 tid,string memory nowPwd)
    isPwdHashUser(nowPwd)
    public view 
    returns(uint256)
    {
        require(balanceOf(msg.sender)>0,"need balance>0");//手数料払ってパスワードハッシュ設定するとPoS用32個以上じゃなくても呼べるよ。
        address eoa_generate=msg.sender;
        bytes32 b32_by_pwdHash = ripemd160(abi.encodePacked(casalt,eoa_generate,userToPwdHash[eoa_generate],block.number/bnm_minute));
        return culcTotp_Bnm(eoa_generate,bnm_minute,tid,b32_by_pwdHash);
    }
    function authTotp_5bn_FromPwdHashUser(address eoa_generate ,uint256 tid,uint256 totp)
    public view 
    returns (bool)
    {
        bytes32 b32_by_pwdHash = ripemd160(abi.encodePacked(casalt,eoa_generate,userToPwdHash[eoa_generate],block.number/bnm_minute));
        
        if(culcTotp_Bnm(eoa_generate,bnm_minute,tid,b32_by_pwdHash)==totp){

            return true;
        }else{
            return false;
        }
    }

    //CR認証用、UC[User-Checked]用。Chaをオーナー又は誰かが出してユーザに送り、ユーザはそれを用いて認証し、パスワードハッシュ持ちユーザはそれを受け取ったらログ・KYC完了できる？
    //cha-side
    mapping (address => uint) public  user_To_LatestBn_LogCha_Call_5bn_PwdHashUser;
    function log_Cha_LatestBn_Call_5bn_FromPwdHashUser(address eoa_generate ,uint256 tid,string memory nowPwd_cha)
    isPwdHashUser(nowPwd_cha)
    public 
    returns(address eoa_g,uint256 cha_totp, uint256 cha_latest_bn)
    {
        require(eoa_generate==msg.sender,"sender");
        uint256 c_totp = callTotp_5bn_ByPwdHashUser(tid,nowPwd_cha);
        user_To_LatestBn_LogCha_Call_5bn_PwdHashUser[eoa_generate]=block.number;
        
        return (
            eoa_generate,
            c_totp,
            user_To_LatestBn_LogCha_Call_5bn_PwdHashUser[eoa_generate]
        );
    }
    //res-side
    mapping (address => uint) public  user_To_LatestBn_LogRes_Auth_5bn_PwdHashUser;
    function log_Res_LatestBn_Auth_5bn_FromPwdHashUser(address eoa_generate ,uint256 tid,uint256 totp, string memory nowPwd_res)
    isPwdHashUser(nowPwd_res)
    public 
    {
        if(authTotp_5bn_FromPwdHashUser(eoa_generate,tid,totp)==true){
            user_To_LatestBn_LogRes_Auth_5bn_PwdHashUser[msg.sender]=block.number;
        }
    }
    //bnの大小関係はCha側=<Res側になる(=<より<が好ましい。blocktime12秒待ってResするとよい)
    //cha=eoa_generate:owner,
    //res=user who is will User-Checked

    //暗号資産取引所のETH管理用？会社と顧客、会社内管理、？？


//アナウンス・広告部================================================================
    bytes32 public kanban_this_contract;//コントラクト看板、看板メッセージのハッシュ値
    function s_Kanban_By_OwnerOne( bytes32 logbytes32 , string memory nowPwd) 
    public
    isOwner
    isPwdHashUser(nowPwd)
    {
        kanban_this_contract = logbytes32;
    }   
}

/*
sample-code_by:

2024-6-23
株式会社SINGULION (Stable Coin / ShinCoin Division  SC事業部 )
CEO Katsuya Nishizawa

Project:ShinCoin® USD10 Wrrapped token for ShinCoin®Sole project etc...

商標ShinCoin®は株式会社SINGULIONの保有する唯一のIPです。


---------
元のコード：https://github.com/Kaz-Naz/0623r6_lrToken_ERC20PWDH_V1
コードや認証技術に関するIPはKatsuya Nishizawa (個人名義)に帰属します。
*/
