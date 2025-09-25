#property strict
#property description "EMA(20/50) + ATR(14) intraday conservative strategy for XAUUSD & US30"
#property version   "1.1"

#include <Trade\Trade.mqh>

#include "../Include/ai_bot/Indicators.mqh"
#include "../Include/ai_bot/Risk.mqh"
#include "../Include/ai_bot/Session.mqh"
#include "../Include/ai_bot/Control.mqh"
#include "../Include/ai_bot/Trade.mqh"
#include "../Include/ai_bot/Logger.mqh"

input bool   InpEnableTrading=true;
input double InpRiskPercent=0.5;
input double InpDailyLossLimit=2.0;

string g_allowed_symbols[] = {"XAUUSD","US30"};
AILogger g_loggers[];
AIControl g_control;
datetime g_last_control_load=0;
double g_daily_loss_limit=2.0;
bool g_control_enabled=true;

int FindSymbolIndex(const string symbol)
  {
   for(int i=0;i<ArraySize(g_allowed_symbols);i++)
     {
      if(StringCompare(g_allowed_symbols[i],symbol)==0)
         return(i);
     }
   return(-1);
  }

void RefreshControl()
  {
   if(TimeCurrent()-g_last_control_load<60)
      return;

   g_last_control_load=TimeCurrent();
   if(AIControlLoader::Load(g_control))
     {
      g_control_enabled=g_control.trading_enabled;
      double control_risk=g_control.risk_percent;
      if(control_risk<=0.0)
         control_risk=InpRiskPercent;
      AIRisk::SetRiskPercent(control_risk);
     }
  }

bool IsTradingAllowedForSymbol(const string symbol)
  {
   if(!InpEnableTrading || !g_control_enabled)
      return(false);

   if(!AISession::IsWithinMYTWindow())
      return(false);

   double daily_loss=AIRisk::CalculateDailyLossPercent(symbol);
   if(daily_loss>=g_daily_loss_limit)
      return(false);

   return(true);
  }

bool EnsureSymbolSubscription(const string symbol)
  {
   if(SymbolInfoInteger(symbol,SYMBOL_SELECT))
      return(true);
   return(SymbolSelect(symbol,true));
  }

void ProcessSymbol(const string symbol,const int index)
  {
   if(index<0 || index>=ArraySize(g_loggers))
      return;

   if(!EnsureSymbolSubscription(symbol))
      return;

   if(!IsTradingAllowedForSymbol(symbol))
      return;

   double atr=0.0;
   if(!AIIndicators::GetATR(symbol,PERIOD_M15,14,1,atr))
      return;

   AITrade::ApplyBreakEven(symbol,atr,g_loggers[index]);

   if(AITrade::HasOpenPosition(symbol))
      return;

   double ema_fast_curr,ema_fast_prev;
   double ema_slow_curr,ema_slow_prev;

   if(!AIIndicators::GetEMA(symbol,PERIOD_M15,20,1,ema_fast_curr))
      return;
   if(!AIIndicators::GetEMA(symbol,PERIOD_M15,20,2,ema_fast_prev))
      return;
   if(!AIIndicators::GetEMA(symbol,PERIOD_M15,50,1,ema_slow_curr))
      return;
   if(!AIIndicators::GetEMA(symbol,PERIOD_M15,50,2,ema_slow_prev))
      return;

   bool bullish_cross=(ema_fast_prev<=ema_slow_prev && ema_fast_curr>ema_slow_curr);
   bool bearish_cross=(ema_fast_prev>=ema_slow_prev && ema_fast_curr<ema_slow_curr);

   if(!bullish_cross && !bearish_cross)
      return;

   double risk_percent=MathMax(0.01,AIRisk::GetRiskPercent());

   if(bullish_cross)
      AITrade::Open(symbol,true,atr,risk_percent,g_loggers[index]);
   else if(bearish_cross)
      AITrade::Open(symbol,false,atr,risk_percent,g_loggers[index]);
  }

int OnInit()
  {
   g_control.Defaults();
   g_control_enabled=g_control.trading_enabled;
   g_daily_loss_limit=InpDailyLossLimit;
   AIRisk::SetRiskPercent(InpRiskPercent);

   ArrayResize(g_loggers,ArraySize(g_allowed_symbols));
   for(int i=0;i<ArraySize(g_allowed_symbols);i++)
     {
      g_loggers[i].Init(g_allowed_symbols[i]);
      EnsureSymbolSubscription(g_allowed_symbols[i]);
     }

   RefreshControl();
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   RefreshControl();

   for(int i=0;i<ArraySize(g_allowed_symbols);i++)
      ProcessSymbol(g_allowed_symbols[i],i);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong deal_ticket=trans.deal;
   if(deal_ticket==0)
      return;

   if(HistoryDealGetInteger(deal_ticket,DEAL_ENTRY)!=DEAL_ENTRY_OUT)
      return;

   string symbol=HistoryDealGetString(deal_ticket,DEAL_SYMBOL);
   int symbol_index=FindSymbolIndex(symbol);
   if(symbol_index<0)
      return;

   ulong position_id=(ulong)HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
   if(position_id==0)
      return;

   if(PositionSelectByTicket(position_id))
      return; // position still open (partial close)

   datetime close_time=(datetime)HistoryDealGetInteger(deal_ticket,DEAL_TIME);
   datetime from=close_time-86400;
   if(!HistorySelect(from,TimeCurrent()))
      return;

   double gross_profit=0.0;
   double volume=0.0;
   double entry_notional=0.0;
   double exit_price=HistoryDealGetDouble(deal_ticket,DEAL_PRICE);
   ulong deals=HistoryDealsTotal();
   for(ulong i=0;i<deals;i++)
     {
      ulong hist_ticket=HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(hist_ticket,DEAL_POSITION_ID)!=position_id)
         continue;

      long entry_type=HistoryDealGetInteger(hist_ticket,DEAL_ENTRY);
      if(entry_type==DEAL_ENTRY_IN)
        {
         double vol=HistoryDealGetDouble(hist_ticket,DEAL_VOLUME);
         double price_in=HistoryDealGetDouble(hist_ticket,DEAL_PRICE);
         volume+=vol;
         entry_notional+=price_in*vol;
        }
      gross_profit+=HistoryDealGetDouble(hist_ticket,DEAL_PROFIT);
     }

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   string deal_comment=HistoryDealGetString(deal_ticket,DEAL_COMMENT);
   double avg_entry=(volume>0.0)?entry_notional/volume:0.0;
   string info="entry="+DoubleToString(avg_entry,digits);
   if(StringLen(deal_comment)>0)
      info=deal_comment+";"+info;
   g_loggers[symbol_index].Log("POSITION_CLOSE",exit_price,volume,gross_profit,info);
  }
