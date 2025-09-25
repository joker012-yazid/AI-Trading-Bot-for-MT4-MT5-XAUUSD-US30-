#property strict

#ifndef __AI_TRADE_MQH__
#define __AI_TRADE_MQH__

#include <Trade\Trade.mqh>
#include "Risk.mqh"
#include "Logger.mqh"

 namespace AITrade
  {
   CTrade trade;

   bool HasOpenPosition(const string symbol)
     {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         if(!PositionSelectByIndex(i))
            continue;
         if(PositionGetString(POSITION_SYMBOL)==symbol)
            return(true);
        }
      return(false);
     }

   bool Open(const string symbol,const bool is_buy,const double atr,const double risk_percent,AILogger &logger)
     {
      if(atr<=0.0)
         return(false);
      MqlTick tick;
      if(!SymbolInfoTick(symbol,tick))
         return(false);

      double price=is_buy?tick.ask:tick.bid;
      if(price<=0.0)
         return(false);

      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double stops_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
      double freeze_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;

      double stop_distance=MathMax(1.5*atr,stops_level);
      if(freeze_level>0.0)
         stop_distance=MathMax(stop_distance,freeze_level);
      double take_distance=2.5*atr;

      double lot=AIRisk::CalculateLot(symbol,risk_percent,stop_distance);
      if(lot<=0.0)
         return(false);

      int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

      double sl=is_buy?price-stop_distance:price+stop_distance;
      double tp=is_buy?price+take_distance:price-take_distance;

      sl=NormalizeDouble(sl,digits);
      tp=NormalizeDouble(tp,digits);

      trade.SetAsyncMode(false);
      trade.SetDeviationInPoints(50);
      trade.SetTypeFillingBySymbol(symbol);

      bool result=false;
      string comment="EMA_ATR";
      if(is_buy)
         result=trade.Buy(lot,symbol,0.0,sl,tp,comment);
      else
         result=trade.Sell(lot,symbol,0.0,sl,tp,comment);

      if(result)
        {
         string info="SL="+DoubleToString(sl,digits)+" TP="+DoubleToString(tp,digits);
         logger.Log(is_buy?"BUY_OPEN":"SELL_OPEN",price,lot,0.0,info);
        }
      return(result);
     }

   void ApplyBreakEven(const string symbol,const double atr,AILogger &logger)
     {
      if(atr<=0.0)
         return;

      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double tolerance=point*0.5;

      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         if(!PositionSelectByIndex(i))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=symbol)
            continue;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double stop=PositionGetDouble(POSITION_SL);
         double volume=PositionGetDouble(POSITION_VOLUME);
         long type=(long)PositionGetInteger(POSITION_TYPE);
         double current_price=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(symbol,SYMBOL_BID):SymbolInfoDouble(symbol,SYMBOL_ASK);

         int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
         double tp=PositionGetDouble(POSITION_TP);

         if(type==POSITION_TYPE_BUY)
           {
            if(current_price-entry>=atr && (stop<entry-tolerance || stop==0.0))
              {
               if(trade.PositionModify(symbol,NormalizeDouble(entry,digits),tp))
                  logger.Log("BREAKEVEN",entry,volume,0.0,"Buy break-even");
              }
           }
         else if(type==POSITION_TYPE_SELL)
           {
            if(entry-current_price>=atr && (stop>entry+tolerance || stop==0.0))
              {
               if(trade.PositionModify(symbol,NormalizeDouble(entry,digits),tp))
                  logger.Log("BREAKEVEN",entry,volume,0.0,"Sell break-even");
              }
           }
        }
     }
  }
#endif
