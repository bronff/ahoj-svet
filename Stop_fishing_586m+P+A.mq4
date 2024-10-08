//+------------------------------------------------------------------+
//|                                          Stop_fishing 586m+P.mq4 |
//|                                   Copyright 2024, Zdeno Brontvay |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property link      "https://www.mql5.com"
#property description "This, a network of orders will appear, which you will close with your hands using the advisor's buttons or give the profit at your discretion to the advisor himself"
#property description "apply separate stop loss and trailing stop values for regular and hedge orders, as well as manage the specific profit closure conditions for hedge orders."
#property strict
#property copyright "befi33@ymail.com"
//--------------------------------------------------------------------
extern bool    buystop              = true;        //povoliť odložený nákup 
extern bool    sellstop             = true;        //povoliť odložený predaj
extern int     maxOrdersinp         = 3;           //Maximum number of active orders allowed
extern bool    RemovePending        = true;        //At Max Orders, delete first pending
extern int     Offset               = 6;           //Offset in pips for pending orders from Ask and Bid prices
extern int     StepB                = 35;          //Krok nákupných objednávok
extern int     StepS                = 35;          //Krok objednávky na predaj
extern double CloseProfitB          = 9;          // Ziskový cieľ pre Buy príkazy
extern double CloseProfitS          = 9;          // Ziskový cieľ pre Sell príkazy
extern double  CloseProfit          = 9;           //uzavrieť všetko na základe celkového zisku
extern int REGULAR_STOP_LOSS_PIPS = 270;
extern int REGULAR_TRAILING_STOP_PIPS = 60;
extern int REGULAR_TRAILING_STEP_PIPS = 25;
extern double  DDTarget             = 2.0;         //Drawdown Target %
extern double  DDTargetDaily        = 3.0;         //Daily Drawdown Target %
extern double  LotB                 = 0.10;        //objem nákupných objednávok
extern double  LotS                 = 0.10;        //Objem predajnej objednávky
extern int     slippage             = 5;           // sklz
extern int     Magic                = 01;

// LiquidationLoss Parameters
extern int     MAX_HORDERS = 1; // Maximum number of hedge orders
extern double  MAX_LOSS = 19.0; // Maximálna povolená strata v USD
extern double  MULTIPLIER = 2.0; // Násobiteľ veľkosti objednávky
extern double  CLOSE_H_PROFIT = 27; // Close all hedge orders when this profit is reached
extern int     HEDGE_MAGIC_NUMBER = 2345; // Unique magic number for the hedge order
extern int HEDGE_STOP_LOSS_PIPS = 500;
extern int HEDGE_TRAILING_STOP_PIPS = 133;
extern int HEDGE_TRAILING_STEP_PIPS = 33;
bool hedgeOrderOpened = false; // Track if a hedge order has already been opened
extern string  TradeComment = "586mP"; // Comment for trades
//--------------------------------------------------------------------
double STOPLEVEL;
double Level = 0;
string val,GV_kn_CB,GV_kn_CS,GV_kn_DD,GV_kn_CA,GV_CPB,GV_CPS,GV_CPA,GV_kn_B,GV_kn_S,GV_kn_A,GV_LB,GV_LS,GV_StB,GV_StS,GV_DDT,GV_DLT,GV_SL,GV_TR,GV_TS;
bool LANGUAGE;
double OOP,Profit=0,ProfitB=0,ProfitS=0,DDPct,DailyLossPct,StartingBalance;
int i,b=0,s=0,tip,maxOrders;

//double adjustedBuyStopPrice = 0; // Point is the smallest possible price change, considering broker's specification.
//double adjustedSellStopPrice = 0;
//double stopLossPrice =0;

// Global variables to store stop loss and trailing stop values
int STOP_LOSS_PIPS;
int TRAILING_STOP_PIPS;
int TRAILING_STEP_PIPS;
//-------------------------------------------------------------------- 

// Funkcia na získanie popisu chyby
string ErrorDescription(int errorCode)
{
    switch(errorCode)
    {
        case 0:   return("No error");
        case 1:   return("No error returned, but the result is unknown");
        case 2:   return("Common error");
        case 3:   return("Invalid trade parameters");
        case 4:   return("Trade server is busy");
        case 5:   return("Old version of the client terminal");
        case 6:   return("No connection with trade server");
        case 7:   return("Not enough rights");
        case 8:   return("Too frequent requests");
        case 9:   return("Malicious operation");
        case 64:  return("Account disabled");
        case 65:  return("Invalid account");
        case 128: return("Trade timeout");
        case 129: return("Invalid price");
        case 130: return("Invalid stops");
        case 131: return("Invalid trade volume");
        case 132: return("Market closed");
        case 133: return("Trade is disabled");
        case 134: return("Not enough money");
        case 135:  return("Price changed");
        case 136:  return("Off quotes");
        case 137:  return("Broker is busy");
        case 138:  return("Requote");
        case 139:  return("Order is locked");
        case 140:  return("Long positions only allowed");
        case 141:  return("Too many requests");
        case 145:  return("Modification denied because order too close to market");
        case 146:  return("Trade context is busy");
        case 147:  return("Expiration denied by broker");
        case 148:  return("The number of open and pending orders has reached the limit set by the broker");
        default:  return("Unknown error");
    }
}

int OnInit()
{ 
   LANGUAGE = TerminalInfoString(TERMINAL_LANGUAGE) == "English";
   if (IsTesting()) ObjectsDeleteAll(0);
   int AN = AccountNumber();
   string GVn = StringConcatenate("cm fishing ", AN, " ", Symbol());
   maxOrders = maxOrdersinp;
   StartingBalance = AccountBalance();
   RectLabelCreate(0, "rl BalanceW", 0, Dpi(195), Dpi(20), Dpi(195), Dpi(70));
   DrawLABEL("rl IsTradeAllowed", Text(LANGUAGE, "Obchod", "Trade"), Dpi(100), Dpi(30), clrRed, ANCHOR_CENTER);

   //-- current dd row
   ButtonCreate(0, "kn close Drawdown" , 0, Dpi(85), Dpi(40), Dpi(80), Dpi(20), Text(LANGUAGE, "Aktuálny DD%", "Current DD%"));
   RectLabelCreate(0, "rl close DDD Pct", 0, Dpi(190), Dpi(40), Dpi(50), Dpi(20));

   //-- daily dd row
   ButtonCreate(0, "rl Loss Rec", 0, Dpi(85), Dpi(62), Dpi(80), Dpi(20), Text(LANGUAGE, "Denný zisk", "Daily Loss")); 
   RectLabelCreate(0, "rl Daily PL P", 0, Dpi(190), Dpi(62), Dpi(50), Dpi(20));

   RectLabelCreate(0, "rl Close Profit", 0, Dpi(195), Dpi(89), Dpi(195), Dpi(90));
   DrawLABEL("rl CloseProfit", Text(LANGUAGE, "Uzatváranie na zisk", "Closing profit"), Dpi(100), Dpi(95), clrBlack, ANCHOR_CENTER);
   ButtonCreate(0, "kn close Buystop" , 0, Dpi(140), Dpi(105), Dpi(50), Dpi(20), Text(LANGUAGE, "X Sell", "X Buys"));
   ButtonCreate(0, "kn close Sellstop" , 0, Dpi(140), Dpi(127), Dpi(50), Dpi(20), Text(LANGUAGE, "X Buy", "X Sells"));
   ButtonCreate(0, "kn close All", 0, Dpi(140), Dpi(149), Dpi(50), Dpi(20), Text(LANGUAGE, "X all", "X all"));

   ButtonCreate(0, "kn Buystop Auto" , 0, Dpi(40), Dpi(105), Dpi(35), Dpi(20), Text(LANGUAGE, "auto", "auto"));
   ButtonCreate(0, "kn Sellstop Auto" , 0, Dpi(40), Dpi(127), Dpi(35), Dpi(20), Text(LANGUAGE, "auto", "auto"));
   ButtonCreate(0, "kn All Auto", 0, Dpi(40), Dpi(149), Dpi(35), Dpi(20), Text(LANGUAGE, "auto", "auto"));

   if(Level != 0) HLineCreate("kn Start", Level);
   
   GV_kn_DD = StringConcatenate(GVn, " close Drawdown");
   if (GlobalVariableCheck(GV_kn_DD)) ObjectSetInteger(0, "kn close Drawdown", OBJPROP_STATE, true);
   GV_kn_CB = StringConcatenate(GVn, " Close Buystop Auto");
   if (GlobalVariableCheck(GV_kn_CB)) ObjectSetInteger(0, "kn Buystop Auto", OBJPROP_STATE, true);
   GV_kn_CS = StringConcatenate(GVn, " Close Sellstop Auto");
   if (GlobalVariableCheck(GV_kn_CS)) ObjectSetInteger(0, "kn Sellstop Auto", OBJPROP_STATE, true);
   GV_kn_CA = StringConcatenate(GVn, " Close All Auto");
   if (GlobalVariableCheck(GV_kn_CA)) ObjectSetInteger(0, "kn All Auto", OBJPROP_STATE, true);
   GV_CPB = StringConcatenate(GVn, " Close Profit Buystop");
   if (GlobalVariableCheck(GV_CPB)) CloseProfitB = GlobalVariableGet(GV_CPB);
   GV_CPS = StringConcatenate(GVn, " Close Profit Sellstop");
   if (GlobalVariableCheck(GV_CPS)) CloseProfitS = GlobalVariableGet(GV_CPS);
   GV_CPA = StringConcatenate(GVn, " Close Profit All");
   if (GlobalVariableCheck(GV_CPA)) CloseProfit = GlobalVariableGet(GV_CPA);
   GV_DDT = StringConcatenate(GVn, " DD Target");
   if (GlobalVariableCheck(GV_DDT)) DDTarget = GlobalVariableGet(GV_DDT);
   GV_DLT = StringConcatenate(GVn, " DL Target");
   if (GlobalVariableCheck(GV_DLT)) DDTargetDaily = GlobalVariableGet(GV_DLT);

   EditCreate(0, "rl DD Target"  , 0, Dpi(138), Dpi(40), Dpi(50), Dpi(20), DoubleToString(DDTarget, 1), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl Daily DD Target"  , 0, Dpi(138), Dpi(62), Dpi(50), Dpi(20), DoubleToString(DDTargetDaily, 1), "Arial", 8, ALIGN_CENTER, false);

   EditCreate(0, "rl Buystop Auto"  , 0, Dpi(90), Dpi(105), Dpi(50), Dpi(20), DoubleToString(CloseProfitB, 2), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl Sellstop Auto" , 0, Dpi(90), Dpi(127), Dpi(50), Dpi(20), DoubleToString(CloseProfitS, 2), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl All Auto", 0, Dpi(90), Dpi(149), Dpi(50), Dpi(20), DoubleToString(CloseProfit, 2) , "Arial", 8, ALIGN_CENTER, false);

   ButtonCreate(0, "kn Clear", 0, Dpi(75), Dpi(25), Dpi(70), Dpi(20), Text(LANGUAGE, "START", "Start") , "Times New Roman", 8, clrBlack, clrGray, clrLightGray, clrNONE, false, CORNER_RIGHT_LOWER);
   RectLabelCreate(0, "rl Buystop", 0, Dpi(190), Dpi(105), Dpi(50), Dpi(20));
   RectLabelCreate(0, "rl Sellstop", 0, Dpi(190), Dpi(127), Dpi(50), Dpi(20));
   RectLabelCreate(0, "rl All", 0, Dpi(190), Dpi(149), Dpi(50), Dpi(20));

   GV_SL = StringConcatenate(GVn, " Stop Loss");
   if (GlobalVariableCheck(GV_SL)) STOP_LOSS_PIPS = (int)GlobalVariableGet(GV_SL);
   GV_TR = StringConcatenate(GVn, " Trail");
   if (GlobalVariableCheck(GV_TR)) TRAILING_STOP_PIPS = (int)GlobalVariableGet(GV_TR);
   GV_TS = StringConcatenate(GVn, " Trail Step");
   if (GlobalVariableCheck(GV_TS)) TRAILING_STEP_PIPS = (int)GlobalVariableGet(GV_TS);
   
   int Y = Dpi(177);
   RectLabelCreate(0, "rl Step Lot", 0, Dpi(195), Y, Dpi(195), Dpi(110)); Y += Dpi(5);
   EditCreate(0, "rl Stop Value", 0, Dpi(95), Y, Dpi(40), Dpi(20), IntegerToString(STOP_LOSS_PIPS), "Arial", 8, ALIGN_CENTER, false);
   DrawLABEL("rl Stop ", Text(LANGUAGE, "StopLoss", "Stop"), Dpi(30), Y + Dpi(10), clrBlack, ANCHOR_CENTER); Y += Dpi(20);
   EditCreate(0, "rl Trail Step", 0, Dpi(190), Y, Dpi(40), Dpi(20), IntegerToString(TRAILING_STEP_PIPS), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl Trail V", 0, Dpi(95), Y, Dpi(40), Dpi(20), IntegerToString(TRAILING_STOP_PIPS), "Arial", 8, ALIGN_CENTER, false);
   DrawLABEL("rl Trail Step L", Text(LANGUAGE, "krok TS", "Step"), Dpi(130), Y + Dpi(10), clrBlack, ANCHOR_CENTER);
   DrawLABEL("rl Trail L", Text(LANGUAGE, "Trail Stop", "Trail"), Dpi(30), Y + Dpi(10), clrBlack, ANCHOR_CENTER); Y += Dpi(30);
   DrawLABEL("rl Step ", Text(LANGUAGE, "krok", "Step"), Dpi(130), Y, clrBlack, ANCHOR_CENTER);
   DrawLABEL("rl Lot ", Text(LANGUAGE, "Objem", "Lot"), Dpi(170), Y, clrBlack, ANCHOR_CENTER); Y += Dpi(10);
   
   GV_LB = StringConcatenate(GVn, " Lot Buystop");
   if (GlobalVariableCheck(GV_LB)) LotB = GlobalVariableGet(GV_LB);
   GV_LS = StringConcatenate(GVn, " Lot Sellstop");
   if (GlobalVariableCheck(GV_LS)) LotS = GlobalVariableGet(GV_LS);
   GV_StB = StringConcatenate(GVn, " Step Buystop");
   if (GlobalVariableCheck(GV_StB)) StepB = (int)GlobalVariableGet(GV_StB);
   GV_StS = StringConcatenate(GVn, " Step Sellstop");
   if (GlobalVariableCheck(GV_StS)) StepS = (int)GlobalVariableGet(GV_StS);
   
   EditCreate(0, "rl Buystop Step" , 0, Dpi(149), Y, Dpi(40), Dpi(20), IntegerToString(StepB), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl Buystop Lot"  , 0, Dpi(190), Y, Dpi(40), Dpi(20), DoubleToString(LotB, 2), "Arial", 8, ALIGN_CENTER, false);
   ButtonCreate(0, "kn open Buystop" , 0, Dpi(65), Y, Dpi(60), Dpi(20), Text(LANGUAGE, "Kúpiť", "Buy")); Y += Dpi(20);

   EditCreate(0, "rl Sellstop Step", 0, Dpi(149), Y, Dpi(40), Dpi(20), IntegerToString(StepS), "Arial", 8, ALIGN_CENTER, false);
   EditCreate(0, "rl Sellstop Lot" , 0, Dpi(190), Y, Dpi(40), Dpi(20), DoubleToString(LotS, 2), "Arial", 8, ALIGN_CENTER, false);
   ButtonCreate(0, "kn open Sellstop" , 0, Dpi(65), Y, Dpi(60), Dpi(20), Text(LANGUAGE, "Predať", "Sell"));

   GV_kn_B = StringConcatenate(GVn, " Buystop");
   if (GlobalVariableCheck(GV_kn_B)) buystop = GlobalVariableGet(GV_kn_B); else GlobalVariableSet(GV_kn_B, buystop);
   
   GV_kn_S = StringConcatenate(GVn, " Sellstop");
   if (GlobalVariableCheck(GV_kn_S)) sellstop = GlobalVariableGet(GV_kn_S); else GlobalVariableSet(GV_kn_S, sellstop);
   
   ObjectSetInteger(0, "kn open Buystop", OBJPROP_STATE, buystop);
   ObjectSetInteger(0, "kn open Sellstop", OBJPROP_STATE, sellstop);
   
   return(INIT_SUCCEEDED);
}

//-------------------------------------------------------------------
void OnTick()
{
    // Check if trading is allowed
    if (!IsTradeAllowed()) 
    {
        DrawLABEL("rl IsTradeAllowed", Text(LANGUAGE, "Obchodovanie je zakázané", "Trade is disabled"), 100, 30, clrRed, ANCHOR_CENTER);
        return;
    }
    else 
    {
        DrawLABEL("rl IsTradeAllowed", Text(LANGUAGE, "Obchod povolený", "Trade is enabled"), 100, 30, clrGreen, ANCHOR_CENTER);
    }
    
    // Retrieve market info and object properties
    STOPLEVEL = MarketInfo(Symbol(), MODE_STOPLEVEL);
    LotB = StringToDouble(ObjectGetString(0, "rl Buystop Lot", OBJPROP_TEXT));
    LotS = StringToDouble(ObjectGetString(0, "rl Sellstop Lot", OBJPROP_TEXT));
    StepB = (int)StringToInteger(ObjectGetString(0, "rl Buystop Step", OBJPROP_TEXT));
    StepS = (int)StringToInteger(ObjectGetString(0, "rl Sellstop Step", OBJPROP_TEXT));

    STOP_LOSS_PIPS = (int)StringToInteger(ObjectGetString(0, "rl Stop Value", OBJPROP_TEXT));
    TRAILING_STOP_PIPS = (int)StringToInteger(ObjectGetString(0, "rl Trail V", OBJPROP_TEXT));
    TRAILING_STEP_PIPS = (int)StringToInteger(ObjectGetString(0, "rl Trail Step", OBJPROP_TEXT));

    DDTarget = StringToDouble(ObjectGetString(0, "rl DD Target", OBJPROP_TEXT));
    ObjectSetString(0, "rl DD Target", OBJPROP_TEXT, DoubleToString(DDTarget, 1));
    DDTargetDaily = StringToDouble(ObjectGetString(0, "rl Daily DD Target", OBJPROP_TEXT));
    ObjectSetString(0, "rl Daily DD Target", OBJPROP_TEXT, DoubleToString(DDTargetDaily, 1));
   
    CloseProfitB = StringToDouble(ObjectGetString(0, "rl Buystop Auto", OBJPROP_TEXT));
    ObjectSetString(0, "rl Buystop Auto", OBJPROP_TEXT, DoubleToString(CloseProfitB, 2));
    CloseProfitS = StringToDouble(ObjectGetString(0, "rl Sellstop Auto", OBJPROP_TEXT));
    ObjectSetString(0, "rl Sellstop Auto", OBJPROP_TEXT, DoubleToString(CloseProfitS, 2));
    CloseProfit = StringToDouble(ObjectGetString(0, "rl All Auto", OBJPROP_TEXT));
    ObjectSetString(0, "rl All Auto", OBJPROP_TEXT, DoubleToString(CloseProfit, 2));
   
    // Synchronize global variables with object properties
    if (LotB != GlobalVariableGet(GV_LB)) GlobalVariableSet(GV_LB, LotB);
    if (LotS != GlobalVariableGet(GV_LS)) GlobalVariableSet(GV_LS, LotS);
    if (StepB != GlobalVariableGet(GV_StB)) GlobalVariableSet(GV_StB, StepB);
    if (StepS != GlobalVariableGet(GV_StS)) GlobalVariableSet(GV_StS, StepS);
    if (DDTarget != GlobalVariableGet(GV_DDT)) GlobalVariableSet(GV_DDT, DDTarget);
    if (DDTargetDaily != GlobalVariableGet(GV_DLT)) GlobalVariableSet(GV_DLT, DDTargetDaily);

    if (STOP_LOSS_PIPS != GlobalVariableGet(GV_SL)) GlobalVariableSet(GV_SL, STOP_LOSS_PIPS);
    if (TRAILING_STOP_PIPS != GlobalVariableGet(GV_TR)) GlobalVariableSet(GV_TR, TRAILING_STOP_PIPS);
    if (TRAILING_STEP_PIPS != GlobalVariableGet(GV_TS)) GlobalVariableSet(GV_TS, TRAILING_STEP_PIPS);

    // Update price level
    ObjectSetDouble(0, "kn Start", OBJPROP_PRICE, Level);
    
    // Count current orders and update balance information
    CountOrders();
    if (AccountEquity() > StartingBalance) StartingBalance = AccountEquity();
    if (b + s == 0) StartingBalance = AccountEquity();
    
    Profit = ProfitB + ProfitS;
    if ((b != 0 || s != 0) && Profit != 0) UpdateTrailingStop(); 
    
    DDPct = (AccountEquity() / StartingBalance - 1) * 100;
    DailyLossPct = CalcDailyLoss();

    // Draw labels for profit and loss
    DrawLABEL("Profit B", DoubleToStr(ProfitB, 2), Dpi(145), Dpi(115), Color(ProfitB < 0, clrRed, clrGreen), ANCHOR_RIGHT);
    DrawLABEL("Profit S", DoubleToStr(ProfitS, 2), Dpi(145), Dpi(137), Color(ProfitS < 0, clrRed, clrGreen), ANCHOR_RIGHT);
    DrawLABEL("Profit A", DoubleToStr(Profit, 2), Dpi(145), Dpi(159), Color(Profit < 0, clrRed, clrGreen), ANCHOR_RIGHT);
    DrawLABEL("Profit DD", DoubleToStr(DDPct, 2) + "%", Dpi(145), Dpi(50), Color(DDPct < 0, clrRed, clrGreen), ANCHOR_RIGHT);
    DrawLABEL("Profit Daily Loss Pct", DoubleToStr(DailyLossPct, 2) + "%", Dpi(145), Dpi(72), Color(DailyLossPct < 0, clrRed, clrGreen), ANCHOR_RIGHT);
    
    // Handle the 'Clear' button
    if (ObjectGetInteger(0, "kn Clear", OBJPROP_STATE))
    {
        Level = Bid;
        ObjectsDeleteAll(0, OBJ_ARROW);
        ObjectsDeleteAll(0, OBJ_TREND);
        ObjectsDeleteAll(0, OBJ_HLINE);
        ObjectSetInteger(0, "kn Clear", OBJPROP_STATE, false);
        HLineCreate("kn Start", Level);
        maxOrders = maxOrdersinp;
    }

    // Handle closing of specific order types based on button states
    if (b != 0 && ObjectGetInteger(0, "kn close Buystop", OBJPROP_STATE))
    {
        if (!CloseAll(OP_BUYSTOP)) Print("Error OrderSend ", GetLastError());
        else ObjectSetInteger(0, "kn close Buystop", OBJPROP_STATE, false);
    }

    if (s != 0 && ObjectGetInteger(0, "kn close Sellstop", OBJPROP_STATE))
    {
        if (!CloseAll(OP_SELLSTOP)) Print("Error OrderSend ", GetLastError());
        else ObjectSetInteger(0, "kn close Sellstop", OBJPROP_STATE, false);
    }

    if (s + b != 0 && ObjectGetInteger(0, "kn close All", OBJPROP_STATE))
    {
        if (!CloseAll(-1)) Print("Error OrderSend ", GetLastError());
        else ObjectSetInteger(0, "kn close All", OBJPROP_STATE, false);
    }

    // Handle automatic closing of orders based on profits or drawdown limits
    HandleAutoClose();

    // Update and check order conditions
    UpdateOrderConditions();

    // Execute any additional trade logic (such as liquidation)
    ExecuteTradeLogic();
}

// Function to handle automatic closing of orders based on profits or drawdown limits
void HandleAutoClose()
{
    if (ObjectGetInteger(0, "kn All Auto", OBJPROP_STATE)) 
    {
        if (GlobalVariableGet(GV_kn_CA) == 0) GlobalVariableSet(GV_kn_CA, 1);
        
        ObjectSetInteger(0, "rl All Auto", OBJPROP_COLOR, clrRed); 
        CloseProfit = StringToDouble(ObjectGetString(0, "rl All Auto", OBJPROP_TEXT));
        if (GlobalVariableGet(GV_CPA) != CloseProfit) GlobalVariableSet(GV_CPA, CloseProfit);
        if (Profit >= CloseProfit && CloseProfit != 0) 
        {
            CloseAll(-1);
            return;
        }
    } 
    else 
    {
        ObjectSetInteger(0, "rl All Auto", OBJPROP_COLOR, clrLightGray); 
        GlobalVariableDel(GV_kn_CA);
    }

    // Drawdown Auto
    if (ObjectGetInteger(0, "kn close Drawdown", OBJPROP_STATE)) 
    {
        if (GlobalVariableGet(GV_kn_DD) == 0) GlobalVariableSet(GV_kn_DD, 1);
        
        ObjectSetInteger(0, "rl DD Target", OBJPROP_COLOR, clrRed); 
        DDTarget = StringToDouble(ObjectGetString(0, "rl DD Target", OBJPROP_TEXT));
        if (GlobalVariableGet(GV_DDT) != DDTarget) GlobalVariableSet(GV_DDT, DDTarget);
        if (DDPct <= -DDTarget) 
        {
            DeleteAllPending();
            maxOrders = 0;
            Alert("Stopped Trading due to Drawdown");
        }
    } 
    else 
    {
        ObjectSetInteger(0, "rl DD Target", OBJPROP_COLOR, clrBlack); 
        GlobalVariableDel(GV_kn_DD);
    }

    // Daily Loss Auto
    if (ObjectGetInteger(0, "rl Loss Rec", OBJPROP_STATE)) 
    {
        if (GlobalVariableGet(GV_kn_DD) == 0) GlobalVariableSet(GV_kn_DD, 1);
        
        ObjectSetInteger(0, "rl Daily DD Target", OBJPROP_COLOR, clrRed); 
        DDTargetDaily = StringToDouble(ObjectGetString(0, "rl Daily DD Target", OBJPROP_TEXT));
        if (GlobalVariableGet(GV_DLT) != DDTargetDaily) GlobalVariableSet(GV_DLT, DDTargetDaily);
        if (DailyLossPct <= -DDTargetDaily) 
        {
            maxOrders = 0;
            Alert("Stopped trading due to Daily Loss Amount");
        }
    } 
    else 
    {
        ObjectSetInteger(0, "rl Daily DD Target", OBJPROP_COLOR, clrBlack); 
        GlobalVariableDel(GV_kn_DD);
    }

    // Sell stop auto
    if (ObjectGetInteger(0, "kn Sellstop Auto", OBJPROP_STATE)) 
    {
        if (GlobalVariableGet(GV_kn_CS) == 0) GlobalVariableSet(GV_kn_CS, 1);
        
        ObjectSetInteger(0, "rl Sellstop Auto", OBJPROP_COLOR, clrRed); 
        CloseProfitS = StringToDouble(ObjectGetString(0, "rl Sellstop Auto", OBJPROP_TEXT));
        if (GlobalVariableGet(GV_CPS) != CloseProfitS) GlobalVariableSet(GV_CPS, CloseProfitS);
        if (ProfitS >= CloseProfitS && CloseProfitS != 0) 
        {
            CloseAll(OP_SELLSTOP);
            return;
        }
    } 
    else 
    {
        ObjectSetInteger(0, "rl Sellstop Auto", OBJPROP_COLOR, clrLightGray); 
        GlobalVariableDel(GV_kn_CS);
    }

    // Buystop auto
    if (ObjectGetInteger(0, "kn Buystop Auto", OBJPROP_STATE)) 
    {
        if (GlobalVariableGet(GV_kn_CB) == 0) GlobalVariableSet(GV_kn_CB, 1);
        
        ObjectSetInteger(0, "rl Buystop Auto", OBJPROP_COLOR, clrRed); 
        CloseProfitB = StringToDouble(ObjectGetString(0, "rl Buystop Auto", OBJPROP_TEXT));
        if (GlobalVariableGet(GV_CPB) != CloseProfitB) GlobalVariableSet(GV_CPB, CloseProfitB);
        if (ProfitB >= CloseProfitB && CloseProfitB != 0) 
        {
            CloseAll(OP_BUYSTOP);
            return;
        }
    } 
    else 
    {
        ObjectSetInteger(0, "rl Buystop Auto", OBJPROP_COLOR, clrLightGray); 
        GlobalVariableDel(GV_kn_CB);
    }
}

// Function to update and check order conditions based on market conditions
void UpdateOrderConditions()
{
    if (buystop != ObjectGetInteger(0, "kn open Buystop", OBJPROP_STATE))
    {
        buystop = ObjectGetInteger(0, "kn open Buystop", OBJPROP_STATE);
        if (GlobalVariableGet(GV_kn_B) != buystop) GlobalVariableSet(GV_kn_B, buystop);
    }
    if (buystop)
    {
        ObjectSetInteger(0, "rl Buystop Step", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "rl Buystop Lot", OBJPROP_COLOR, clrRed);
    }
    else
    {
        ObjectSetInteger(0, "rl Buystop Step", OBJPROP_COLOR, clrLightGray);  
        ObjectSetInteger(0, "rl Buystop Lot", OBJPROP_COLOR, clrLightGray);  
    }

    if (sellstop != ObjectGetInteger(0, "kn open Sellstop", OBJPROP_STATE))
    {
        sellstop = ObjectGetInteger(0, "kn open Sellstop", OBJPROP_STATE);
        if (GlobalVariableGet(GV_kn_S) != sellstop) GlobalVariableSet(GV_kn_S, sellstop);
    }
    if (sellstop)
    {
        ObjectSetInteger(0, "rl Sellstop Step", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "rl Sellstop Lot", OBJPROP_COLOR, clrRed);
    }
    else
    {
        ObjectSetInteger(0, "rl Sellstop Step", OBJPROP_COLOR, clrLightGray);  
        ObjectSetInteger(0, "rl Sellstop Lot", OBJPROP_COLOR, clrLightGray);  
    }

    if (Bid <= Level - StepB * Point && Level != 0)
    {
        if (b >= maxOrders && !RemovePending)
        {
            Print("Maximum number of active Buys (", maxOrders, ") reached. No new Buys will be placed.");
            return;
        }
        else if (b >= maxOrders && RemovePending)
        {
            DeletePending(OP_BUYSTOP);
        }
        if (b < maxOrders && buystop && AccountFreeMarginCheck(Symbol(), OP_BUY, LotB) > 0)
        {
            double adjustedBuyStopPrice = Ask + Offset * Point;
            double stopLossPrice = adjustedBuyStopPrice - (STOP_LOSS_PIPS * Point);
            if (STOP_LOSS_PIPS == 0) stopLossPrice = 0;
            int ticket = OrderSend(Symbol(), OP_BUYSTOP, LotB, adjustedBuyStopPrice, slippage, stopLossPrice, 0, "Buy Stop Order", Magic, 0, clrGreen);
            if (ticket < 0)
            {
                Print("Error opening Buy Stop order: ", ErrorDescription(GetLastError()));
            }
            else Level = Bid;
        }
    }

    if (Bid >= Level + StepS * Point && Level != 0)
    {
        if (s >= maxOrders && !RemovePending)
        {
            Print("Maximum number of active Sells(", maxOrders, ") reached. No new Sells will be placed.");
            return;
        }
        else if (s >= maxOrders && RemovePending)
        {
            DeletePending(OP_SELLSTOP);
        }
        if (s < maxOrders && sellstop && AccountFreeMarginCheck(Symbol(), OP_SELL, LotS) > 0)
        {
            double adjustedSellStopPrice = Bid - Offset * Point;
            double stopLossPrice = adjustedSellStopPrice + (STOP_LOSS_PIPS * Point);
            if (STOP_LOSS_PIPS == 0) stopLossPrice = 0;
            int ticket = OrderSend(Symbol(), OP_SELLSTOP, LotS, adjustedSellStopPrice, slippage, stopLossPrice, 0, "Sell Stop Order", Magic, 0, clrDarkOrange);
            if (ticket < 0)
            {
                Print("Error opening Sell Stop order: ", ErrorDescription(GetLastError()));
            }
            else Level = Bid;
        }
    }
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
color Color(bool P, color c, color d)
{
   if (P) return(c);
   else return(d);
}

void DrawLABEL(string name, string Name, int X, int Y, color clr, ENUM_ANCHOR_POINT align = ANCHOR_RIGHT)
{
   if (ObjectFind(name) == -1)
   {
      ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
      ObjectSet(name, OBJPROP_CORNER, 1);
      ObjectSet(name, OBJPROP_XDISTANCE, X);
      ObjectSet(name, OBJPROP_YDISTANCE, Y);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, align); 
   }
   ObjectSetText(name, Name, 8, "Arial", clr);
}

bool HLineCreate(const string name = "HLine", double price = 0)
{
   ResetLastError(); 
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) 
   { 
      Print(__FUNCTION__, ": failed to create a horizontal line! Error code = ", GetLastError()); 
      return(false); 
   } 
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow); 
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT); 
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); 
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false); 
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true); 
   return(true); 
}

string Text(bool P, string c, string d)
{
   if (P) return(d);
   else return(c);
}

bool ButtonCreate(const long chart_ID = 0, const string name = "Button", const int sub_window = 0, const long x = 0, const long y = 0, const int width = 50, const int height = 18, const string text = "Button", const string font = "Arial", const int font_size = 8, const color clr = clrBlack, const color clrON = clrLightGray, const color clrOFF = clrLightGray, const color border_clr = clrNONE, const bool state = false, const ENUM_BASE_CORNER CORNER = CORNER_RIGHT_UPPER)
{
   if (ObjectFind(chart_ID, name) == -1)
   {
      ObjectCreate(chart_ID, name, OBJ_BUTTON, sub_window, 0, 0);
      ObjectSetInteger(chart_ID, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(chart_ID, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(chart_ID, name, OBJPROP_CORNER, CORNER);
      ObjectSetString(chart_ID, name, OBJPROP_FONT, font);
      ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(chart_ID, name, OBJPROP_BACK, 0);
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, 0);
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, 0);
      ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, 1);
      ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, 1);
      ObjectSetInteger(chart_ID, name, OBJPROP_STATE, state);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_BORDER_COLOR, border_clr);
   color back_clr;
   if (ObjectGetInteger(chart_ID, name, OBJPROP_STATE)) back_clr = clrON; else back_clr = clrOFF;
   ObjectSetInteger(chart_ID, name, OBJPROP_BGCOLOR, back_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetString(chart_ID, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chart_ID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_ID, name, OBJPROP_YDISTANCE, y);
   return(true);
}

bool RectLabelCreate(const long chart_ID = 0, const string name = "RectLabel", const int sub_window = 0, const long x = 0, const long y = 0, const int width = 50, const int height = 18, const color back_clr = clrWhite, const color clr = clrBlack, const ENUM_LINE_STYLE style = STYLE_SOLID, const int line_width = 1, const bool back = false, const bool selection = false, const bool hidden = true, const long z_order = 0)
{
   ResetLastError();
   if (ObjectFind(chart_ID, name) == -1)
   {
      ObjectCreate(chart_ID, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0);
      ObjectSetInteger(chart_ID, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chart_ID, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
      ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, line_width);
      ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection);
      ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
      ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
   }
   ObjectSetInteger(chart_ID, name, OBJPROP_BGCOLOR, back_clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chart_ID, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(chart_ID, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(chart_ID, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_ID, name, OBJPROP_YDISTANCE, y);
   return(true);
}

bool EditCreate(const long chart_ID = 0, const string name = "Edit", const int sub_window = 0, const int x = 0, const int y = 0, const int width = 50, const int height = 18, const string text = "Text", const string font = "Arial", const int font_size = 8, const ENUM_ALIGN_MODE align = ALIGN_RIGHT, const bool read_only = true, const ENUM_BASE_CORNER corner = CORNER_RIGHT_UPPER, const color clr = clrBlack, const color back_clr = clrWhite, const color border_clr = clrNONE, const bool back = false, const bool selection = false, const bool hidden = true, const long z_order = 0)
{
   ResetLastError(); 
   if (!ObjectCreate(chart_ID, name, OBJ_EDIT, sub_window, 0, 0)) 
   { 
      Print(__FUNCTION__, ": nepodarilo sa vytvoriť objekt ", name, "! Kód chyby = ", GetLastError()); 
      return(false); 
   } 
   ObjectSetInteger(chart_ID, name, OBJPROP_XDISTANCE, x); 
   ObjectSetInteger(chart_ID, name, OBJPROP_YDISTANCE, y); 
   ObjectSetInteger(chart_ID, name, OBJPROP_XSIZE, width); 
   ObjectSetInteger(chart_ID, name, OBJPROP_YSIZE, height); 
   ObjectSetString(chart_ID, name, OBJPROP_TEXT, text); 
   ObjectSetString(chart_ID, name, OBJPROP_FONT, font); 
   ObjectSetInteger(chart_ID, name, OBJPROP_FONTSIZE, font_size); 
   ObjectSetInteger(chart_ID, name, OBJPROP_ALIGN, align); 
   ObjectSetInteger(chart_ID, name, OBJPROP_READONLY, read_only); 
   ObjectSetInteger(chart_ID, name, OBJPROP_CORNER, corner); 
   ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr); 
   ObjectSetInteger(chart_ID, name, OBJPROP_BGCOLOR, back_clr); 
   ObjectSetInteger(chart_ID, name, OBJPROP_BORDER_COLOR, border_clr); 
   ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back); 
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection); 
   ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection); 
   ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden); 
   ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order); 
   return(true); 
}

//+------------------------------------------------------------------+ 
void OnDeinit(const int reason)
{
   if (!IsTesting())
   {
      ObjectsDeleteAll(0, "Profit");
      ObjectsDeleteAll(0, "kn");
      ObjectsDeleteAll(0, "rl");
      ObjectsDeleteAll(0, "Equity");
      ObjectsDeleteAll(0, "FreeMargin");
   }
   Comment("");
}

//+------------------------------------------------------------------+
bool CloseAll(int type)
{
   bool error = true;
   int j, err, nn = 0, OT;
   
   while (true)
   {
      for (j = OrdersTotal() - 1; j >= 0; j--)
      {
         if (OrderSelect(j, SELECT_BY_POS))
         {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
            {
               OT = OrderType();
               if ((type == -1 || type == OP_BUYSTOP) && OT == OP_BUY) 
               {
                  error = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Bid, Digits), slippage, Blue);
               }
               if ((type == -1 || type == OP_BUYSTOP) && OT == OP_BUYSTOP) 
               {
                  error = OrderDelete(OrderTicket(), Blue);
               }
               else if ((type == -1 || type == OP_SELLSTOP) && OT == OP_SELL)
               {
                  error = OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(Ask, Digits), slippage, Red);
               }
               else if ((type == -1 || type == OP_SELLSTOP) && OT == OP_SELLSTOP)
               {
                  error = OrderDelete(OrderTicket(), Red);
               }
               if (!error) 
               {
                  err = GetLastError();
                  if (err < 2) continue;
                  if (err == 129) 
                  {
                     RefreshRates();
                     continue;
                  }
                  if (err == 146) 
                  {
                     if (IsTradeContextBusy()) Sleep(2000);
                     continue;
                  }
                  Print("Chyba ", err, " uzavretie objednávky N ", OrderTicket(), "     ", TimeToStr(TimeCurrent(), TIME_SECONDS));
               }
            }
         }
      }
      int n = 0;
      for (j = 0; j < OrdersTotal(); j++)
      {
         if (OrderSelect(j, SELECT_BY_POS))
         {
            if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
            {
               if (type != -1 && type != OrderType()) continue;
               n++;
            }
         }  
      }
      if (type == -1)
      {
         Level = 0;
         ObjectsDeleteAll(0, OBJ_HLINE);
         break;
      }
      nn++;
      if (nn > 10) 
      {
         Alert(Symbol(), " Nepodarilo sa uzavrieť všetky objednávky, zostalo ", n);
         return(false); 
      }
      Sleep(1000);
      RefreshRates();
   }
   return(true);
}

//+------------------------------------------------------------------+
bool DeletePending(int type)
{
   bool error = true;
   int j, OT, ticket = 0;
   double prc = 0;
   
   for (j = OrdersTotal() - 1; j >= 0; j--)
   {
      if (OrderSelect(j, SELECT_BY_POS))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            OT = OrderType();
            if (OT == OP_BUYSTOP && type == OT)
            {
               if (prc == 0)
               {
                  prc = OrderOpenPrice();
                  ticket = OrderTicket();
               }
               if (OrderOpenPrice() > prc)
               {
                  prc = OrderOpenPrice();
                  ticket = OrderTicket();
               }
            }
            if (OT == OP_SELLSTOP && type == OT)
            {
               if (prc == 0)
               {
                  prc = OrderOpenPrice();
                  ticket = OrderTicket();
               }
               if (OrderOpenPrice() < prc)
               {
                  prc = OrderOpenPrice();
                  ticket = OrderTicket();
               }
            }
         }
      }
   }
   if (ticket == 0)
   {
      Print("No Pending Orders to Delete");
   }
   if (ticket > 0)
   {
      error = OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
      if (OrderType() == OP_BUYSTOP) 
      {
         error = OrderDelete(OrderTicket(), clrBlue);
      }
      if (OrderType() == OP_SELLSTOP)
      {
         error = OrderDelete(OrderTicket(), clrRed);
      }
   }
   CountOrders();
   Sleep(1000);
   RefreshRates();
   return(true);
}

bool DeleteAllPending()
{
   bool error = true;
   int j;
   
   for (j = OrdersTotal() - 1; j >= 0; j--)
   {
      if (OrderSelect(j, SELECT_BY_POS))
      {
         if (OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         {
            if (OrderType() == OP_BUYSTOP) 
            {
               error = OrderDelete(OrderTicket(), clrBlue);
            }
            if (OrderType() == OP_SELLSTOP)
            {
               error = OrderDelete(OrderTicket(), clrRed);
            }
         }
      }
   }

   CountOrders();
   return(true);
}

//+------------------------------------------------------------------+
double CalcTotalLoss()
{
   double profit = 0;
   int j;
   
   for (j = 0; j < OrdersTotal(); j++)
   {    
      if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
      { 
         if (OrderSymbol() == Symbol() && Magic == OrderMagicNumber())
         {
            profit += OrderProfit() + OrderCommission() + OrderSwap(); 
         }
      }
   } 
   
   for (j = 0; j < OrdersHistoryTotal(); j++)
   {    
      if (OrderSelect(j, SELECT_BY_POS, MODE_HISTORY))
      { 
         if (OrderSymbol() == Symbol() && Magic == OrderMagicNumber())
         {
            if (TimeMonth(OrderCloseTime()) == TimeMonth(TimeCurrent()) && TimeYear(OrderCloseTime()) == TimeYear(TimeCurrent()))
            {
               profit += OrderProfit() + OrderCommission() + OrderSwap(); 
            }
         }
      }
   } 
   profit = profit / AccountBalance() * 100;
   return(profit);
}

double CalcDailyLoss()
{
   double profit = 0;
   int j;
   
   for (j = 0; j < OrdersTotal(); j++)
   {    
      if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
      { 
         if (OrderSymbol() == Symbol() && Magic == OrderMagicNumber())
         {
            profit += OrderProfit() + OrderCommission() + OrderSwap(); 
         }
      }
   } 
   
   for (j = 0; j < OrdersHistoryTotal(); j++)
   {    
      if (OrderSelect(j, SELECT_BY_POS, MODE_HISTORY))
      { 
         if (OrderSymbol() == Symbol() && Magic == OrderMagicNumber())
         {
            if (TimeDay(OrderCloseTime()) == TimeDay(TimeCurrent()) && TimeMonth(OrderCloseTime()) == TimeMonth(TimeCurrent()) && TimeYear(OrderCloseTime()) == TimeYear(TimeCurrent()))
            {
               profit += OrderProfit() + OrderCommission() + OrderSwap(); 
            }
         }
      }
   } 
   profit = profit / AccountBalance() * 100;
   return(profit);
}

void CountOrders()
{
   b = 0;
   s = 0;
   ProfitB = 0;
   ProfitS = 0;
   for (int j = 0; j < OrdersTotal(); j++) // Nahradenie 'i' za 'j'
   {    
      if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
      { 
         if (OrderSymbol() == Symbol() && Magic == OrderMagicNumber())
         { 
            tip = OrderType(); 
            OOP = NormalizeDouble(OrderOpenPrice(), Digits);
            Profit = OrderProfit() + OrderSwap() + OrderCommission();
            if (tip == OP_BUY || tip == OP_BUYSTOP)             
            {  
               ProfitB += Profit;
               b++; 
            }                                         
            if (tip == OP_SELL || tip == OP_SELLSTOP)        
            {
               ProfitS += Profit;
               s++;
            } 
         }
      }
   } 
}

void UpdateTrailingStop() 
{
   bool check;
   for (int j = OrdersTotal() - 1; j >= 0; j--) // Nahradenie 'i' za 'j'
   {
      if (OrderSelect(j, SELECT_BY_POS) && OrderSymbol() == Symbol() && OrderMagicNumber() == HEDGE_MAGIC_NUMBER)
      {
         double currentProfit = OrderType() == OP_BUY ? Bid - OrderOpenPrice() : OrderOpenPrice() - Ask;
         if (currentProfit > TRAILING_STOP_PIPS * Point) 
         {
            double newStopLoss = OrderType() == OP_BUY ? Bid - TRAILING_STOP_PIPS * Point : Ask + TRAILING_STOP_PIPS * Point;
            if ((OrderType() == OP_BUY && OrderStopLoss() < newStopLoss) || (OrderType() == OP_SELL && OrderStopLoss() > newStopLoss)) 
            {
               if (MathAbs(OrderStopLoss() - newStopLoss) >= TRAILING_STEP_PIPS * Point) 
               {
                  check = OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrNONE);
               }
            }
         }
      }
   }
}


//+-------------------------------------------------------------------------------------+
//| MoveStopLossToHedgeTrailingStop - Funkcia pre posun Stop-Loss a auto pokračovanie   |
//+-------------------------------------------------------------------------------------+
// Deklarácia funkcie OpenInitialOrders
void OpenInitialOrders(bool usePendingOrders);

//+-------------------------------------------------------------------+
//| MoveStopLossToHedgeTrailingStop - Funkcia pre posun Stop-Loss     |
//+-------------------------------------------------------------------+
void MoveStopLossToTrailingStop(int ticket, bool isHedgeOrder)
{
    if (OrderSelect(ticket, SELECT_BY_TICKET))
    {
        double openPrice = OrderOpenPrice();
        double currentPrice = OrderType() == OP_BUY ? Bid : Ask;
        int trailingStopPips = isHedgeOrder ? HEDGE_TRAILING_STOP_PIPS : REGULAR_TRAILING_STOP_PIPS;
        double newStopLoss = OrderType() == OP_BUY ? currentPrice - trailingStopPips * Point : currentPrice + trailingStopPips * Point;
        double stopLoss = OrderStopLoss();
        
        // Pridanie Take Profit výpočtu
        double newTakeProfit = OrderType() == OP_BUY ? openPrice + CLOSE_H_PROFIT * Point : openPrice - CLOSE_H_PROFIT * Point;

        // Upravte nový Stop-Loss tak, aby rešpektoval minimálnu stop úroveň brokera
        double minStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
        if (OrderType() == OP_BUY && (newStopLoss < openPrice + minStopLevel))
        {
            newStopLoss = openPrice + minStopLevel;
        }
        else if (OrderType() == OP_SELL && (newStopLoss > openPrice - minStopLevel))
        {
            newStopLoss = openPrice - minStopLevel;
        }

        bool result;
        // Posuň stop-loss a nastav take-profit
        if (OrderType() == OP_BUY && (stopLoss == 0 || currentPrice - stopLoss >= HEDGE_TRAILING_STEP_PIPS * Point))
        {
            result = OrderModify(ticket, openPrice, newStopLoss, newTakeProfit, 0, clrGreen);
            if (result)
                Print("Trailing Stop and Take Profit moved for ", isHedgeOrder ? "Hedge Buy order" : "Regular Buy order");
            else
                Print("Error moving Trailing Stop and Take Profit for ", isHedgeOrder ? "Hedge Buy order" : "Regular Buy order", ": ", ErrorDescription(GetLastError()));
        }
        else if (OrderType() == OP_SELL && (stopLoss - currentPrice >= HEDGE_TRAILING_STEP_PIPS * Point))
        {
            result = OrderModify(ticket, openPrice, newStopLoss, newTakeProfit, 0, clrRed);
            if (result)
                Print("Trailing Stop and Take Profit moved for ", isHedgeOrder ? "Hedge Sell order" : "Regular Sell order");
            else
                Print("Error moving Trailing Stop and Take Profit for ", isHedgeOrder ? "Hedge Sell order" : "Regular Sell order", ": ", ErrorDescription(GetLastError()));
        }
    }
}

void MoveStopLossToHedgeTrailingStop(int ticket)
{
    if (OrderSelect(ticket, SELECT_BY_TICKET))
    {
        double currentPrice = OrderType() == OP_BUY ? Bid : Ask;
        int trailingStopPips = HEDGE_TRAILING_STOP_PIPS;
        double newStopLoss = OrderType() == OP_BUY ? currentPrice - trailingStopPips * Point : currentPrice + trailingStopPips * Point;
        double stopLoss = OrderStopLoss();

        // Nastavenie minimálneho stop levelu a posunutie hedge Stop-Lossu
        double minStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
        if (OrderType() == OP_BUY && (newStopLoss < OrderOpenPrice() + minStopLevel))
        {
            newStopLoss = OrderOpenPrice() + minStopLevel;
        }
        else if (OrderType() == OP_SELL && (newStopLoss > OrderOpenPrice() - minStopLevel))
        {
            newStopLoss = OrderOpenPrice() - minStopLevel;
        }

        if ((OrderType() == OP_BUY && currentPrice - stopLoss >= HEDGE_TRAILING_STEP_PIPS * Point) ||
            (OrderType() == OP_SELL && stopLoss - currentPrice >= HEDGE_TRAILING_STEP_PIPS * Point))
        
        if (OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrGreen))
        {
        Print("OrderModify successful for ticket: ", ticket);
        }
        else
        {
        Print("OrderModify failed for ticket: ", ticket, ". Error: ", ErrorDescription(GetLastError()));
        }

    }
}

void MoveStopLossToRegularTrailingStop(int ticket)
{
    if (OrderSelect(ticket, SELECT_BY_TICKET))
    {
        double currentPrice = OrderType() == OP_BUY ? Bid : Ask;
        int trailingStopPips = REGULAR_TRAILING_STOP_PIPS;
        double newStopLoss = OrderType() == OP_BUY ? currentPrice - trailingStopPips * Point : currentPrice + trailingStopPips * Point;
        double stopLoss = OrderStopLoss();

        // Nastavenie minimálneho stop levelu a posunutie regular Stop-Lossu
        double minStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
        if (OrderType() == OP_BUY && (newStopLoss < OrderOpenPrice() + minStopLevel))
        {
            newStopLoss = OrderOpenPrice() + minStopLevel;
        }
        else if (OrderType() == OP_SELL && (newStopLoss > OrderOpenPrice() - minStopLevel))
        {
            newStopLoss = OrderOpenPrice() - minStopLevel;
        }

        if ((OrderType() == OP_BUY && currentPrice - stopLoss >= REGULAR_TRAILING_STEP_PIPS * Point) ||
            (OrderType() == OP_SELL && stopLoss - currentPrice >= REGULAR_TRAILING_STEP_PIPS * Point))
            
         if (OrderModify(ticket, OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrGreen))
        {
        Print("OrderModify successful for ticket: ", ticket);
        }
        else
        {
        Print("OrderModify failed for ticket: ", ticket, ". Error: ", ErrorDescription(GetLastError()));
        }

    }
}
//+------------------------------------------------------------------+
//| CloseAllOrders - Funkcia pre uzavretie všetkých príkazov          |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
    for (int j = OrdersTotal() - 1; j >= 0; j--)
    {
        if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderType() <= OP_SELL && OrderSymbol() == Symbol())
            {
                bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrRed);
                if (result)
                    Print("Order closed: ", OrderTicket());
                else
                    Print("Error closing order: ", OrderTicket(), " - ", ErrorDescription(GetLastError()));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| CloseHedgeOrders - Funkcia pre uzavretie všetkých hedge príkazov  |
//+------------------------------------------------------------------+
void CloseHedgeOrders()
{
    for (int j = OrdersTotal() - 1; j >= 0; j--)
    {
        if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
        {
            // Kontrola, či ide o hedge príkaz
            if (OrderType() <= OP_SELL && OrderSymbol() == Symbol() && OrderMagicNumber() == HEDGE_MAGIC_NUMBER)
            {
                // Výpočet aktuálneho zisku príkazu
                double profit = OrderProfit() + OrderSwap() + OrderCommission();

                // Uzavretie príkazu len vtedy, ak je zisk väčší alebo rovný CLOSE_H_PROFIT
                if (profit >= CLOSE_H_PROFIT)
                {
                    bool result = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 3, clrRed);
                    if (result)
                        Print("Hedge order closed with profit: ", OrderTicket(), " Profit: ", profit);
                    else
                        Print("Error closing hedge order: ", OrderTicket(), " - ", ErrorDescription(GetLastError()));
                }
                else
                {
                    Print("Hedge order not closed (profit too low): ", OrderTicket(), " Profit: ", profit);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
//| Liquidation Loss Market - Hlavná obchodná logika                  |
//+------------------------------------------------------------------+
void ExecuteTradeLogic()
{
    double totalLoss = 0.0;
    double totalBuyLots = 0.0;
    double totalSellLots = 0.0;
    double largestLoss = 0.0;
    int largestLossTicket = -1;
    int largestLossType = -1;
    int hedgeOrdersCount = 0;
    double hedgeOrdersProfit = 0.0;
    double totalProfit = 0.0;  // Celkový zisk základných a hedge príkazov

    for (int j = 0; j < OrdersTotal(); j++) 
    {
        if (!OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol()) continue;

        double orderProfit = OrderProfit();
        totalLoss += orderProfit;
        totalProfit += orderProfit;  // Pridajte profit do celkového zisku

        if (orderProfit < largestLoss)
        {
            largestLoss = orderProfit;
            largestLossTicket = OrderTicket();
            largestLossType = OrderType();
        }

        if (OrderType() == OP_BUY)
        {
            totalBuyLots += OrderLots();
        }
        else if (OrderType() == OP_SELL)
        {
            totalSellLots += OrderLots();
        }

        // Počítajte hedge príkazy a ich celkový zisk
        if (OrderMagicNumber() == HEDGE_MAGIC_NUMBER)
        {
            hedgeOrdersCount++;
            hedgeOrdersProfit += orderProfit;

            // Aplikácia trailing stop na hedge príkaz
            MoveStopLossToTrailingStop(OrderTicket(), true);
        }
    }

    // Uzavrite všetky príkazy, ak je celkový zisk vyšší ako súčet CloseProfitB + CloseProfitS
    if (totalProfit >= (CloseProfitB + CloseProfitS + CLOSE_H_PROFIT))
    {
        Print("Closing all orders due to total profit target reached.");
        CloseAllOrders();

        // Otvorte nové príkazy (pending alebo market) po uzavretí
        OpenInitialOrders(true); // Zmeňte na false, ak chcete otvoriť market príkazy
        return;  // Ukončite funkciu po uzavretí všetkých príkazov
    }

    // Uzavrite hedge príkazy, ak ich zisk presahuje CLOSE_H_PROFIT
    if (hedgeOrdersProfit >= CLOSE_H_PROFIT)
    {
        Print("Closing all hedge orders due to profit limit reached.");
        CloseAllOrders();

        // Otvorte nové príkazy (pending alebo market) po uzavretí
        OpenInitialOrders(true); // Zmeňte na false, ak chcete otvoriť market príkazy
        return;  // Ukončite funkciu po uzavretí všetkých príkazov
    }

     // Logika pre otvorenie nového hedge príkazu, iba ak ešte nebol otvorený
    if (!hedgeOrderOpened && MathAbs(totalLoss) >= MAX_LOSS && largestLossTicket != -1)
    {
        double lotSize = NormalizeDouble(MathAbs(totalBuyLots - totalSellLots), 2);
        lotSize *= MULTIPLIER;
        int hedgeSlippage = 3; 
        double stopLoss = HEDGE_STOP_LOSS_PIPS * Point;
        double takeProfit = 0; // no take profit
        int ticket = -1;
        string comment = TradeComment + " Magic: " + IntegerToString(HEDGE_MAGIC_NUMBER);

        if (largestLossType == OP_SELL)
        {
            // Otvorenie Buy market hedge príkazu
            ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, hedgeSlippage, Ask - stopLoss, takeProfit, comment, HEDGE_MAGIC_NUMBER, 0, clrGreen);
        }
        else if (largestLossType == OP_BUY)
        {
            // Otvorenie Sell market hedge príkazu
            ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, hedgeSlippage, Bid + stopLoss, takeProfit, comment, HEDGE_MAGIC_NUMBER, 0, clrRed);
        }

        if (ticket < 0)
        {
            Print("Error opening Hedge Market Order: ", ErrorDescription(GetLastError()));
        }
        else
        {
            Print("Hedge Market Order opened successfully at Loss Level");
            hedgeOrderOpened = true;  // Mark that a hedge order has been opened
            MoveStopLossToTrailingStop(ticket, true);
        }
    }
}

// Definícia funkcie OpenInitialOrders
void OpenInitialOrders(bool usePendingOrders)
{
    double lotSize = 0.1; // Nastavte veľkosť lotu pre nové príkazy

    if (usePendingOrders)
    {
        // Otvorenie nových pending BUY STOP a SELL STOP príkazov
        double buyStopPrice = Ask + 50 * Point; // Nastavte požadovanú cenu
        double sellStopPrice = Bid - 50 * Point; // Nastavte požadovanú cenu

        int buyTicket = OrderSend(Symbol(), OP_BUYSTOP, lotSize, buyStopPrice, 3, 0, 0, "Regular B Order", 0, 0, clrGreen);
        if (buyTicket < 0)
        {
            Print("Error opening pending Buy Stop order: ", ErrorDescription(GetLastError()));
        }

        int sellTicket = OrderSend(Symbol(), OP_SELLSTOP, lotSize, sellStopPrice, 3, 0, 0, "Regular S Order", 0, 0, clrRed);
        if (sellTicket < 0)
        {
            Print("Error opening pending Sell Stop order: ", ErrorDescription(GetLastError()));
        }
    }
    else
    {
        // Otvorenie nových market BUY a SELL príkazov
        int buyTicket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, 0, 0, "Initial Buy Market Order", 0, 0, clrGreen);
        if (buyTicket < 0)
        {
            Print("Error opening initial Buy Market order: ", ErrorDescription(GetLastError()));
        }

        int sellTicket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, 0, 0, "Initial Sell Market Order", 0, 0, clrRed);
        if (sellTicket < 0)
        {
            Print("Error opening initial Sell Market order: ", ErrorDescription(GetLastError()));
        }
    }
}



int Dpi(int Size)
{
    int screen_dpi=TerminalInfoInteger(TERMINAL_SCREEN_DPI);
    int base_width=Size;
    int width=(base_width*screen_dpi)/96;
    int scale_factor=(TerminalInfoInteger(TERMINAL_SCREEN_DPI)*100)/96;
    width=(base_width*scale_factor)/100;
    return(width);
}
