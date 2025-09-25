#property strict

#ifndef __AI_RISK_MQH__
#define __AI_RISK_MQH__

namespace AIRisk
  {
   double g_risk_percent=0.5;

   void SetRiskPercent(const double percent)
     {
      if(percent>0.0)
         g_risk_percent=percent;
     }

   double GetRiskPercent()
     {
      return(g_risk_percent);
     }

   double NormalizeVolume(const string symbol,double lots)
     {
      double min_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
      double max_lot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      double lot_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
      int lot_digits=(int)SymbolInfoInteger(symbol,SYMBOL_VOLUME_DIGITS);

      if(lot_step<=0.0)
         lot_step=min_lot;

      if(lot_step>0.0)
        {
         lots=MathFloor(lots/lot_step+0.0000001)*lot_step;
        }

      lots=NormalizeDouble(lots,lot_digits);
      lots=MathMax(min_lot,lots);
      lots=MathMin(max_lot,lots);
      return(lots);
     }

   double CalculateLot(const string symbol,const double risk_percent,const double stop_distance)
     {
      if(risk_percent<=0.0 || stop_distance<=0.0)
         return(0.0);

      double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity<=0.0)
         equity=AccountInfoDouble(ACCOUNT_BALANCE);
      if(equity<=0.0)
         return(0.0);

      double risk_amount=equity*(risk_percent/100.0);
      double tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      double tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(tick_value<=0.0 || tick_size<=0.0 || point<=0.0)
         return(0.0);

      double value_per_point=tick_value/tick_size;
      double risk_per_lot=(stop_distance/point)*value_per_point;
      if(risk_per_lot<=0.0)
         return(0.0);

      double lots=risk_amount/risk_per_lot;
      return(NormalizeVolume(symbol,lots));
     }

   double CalculateDailyLossPercent(const string symbol)
     {
      datetime now=TimeCurrent();
      MqlDateTime tm;
      TimeToStruct(now,tm);
      tm.hour=0;
      tm.min=0;
      tm.sec=0;
      datetime start_of_day=StructToTime(tm);
      if(!HistorySelect(start_of_day,now))
         return(0.0);

      double net=0.0;
      ulong deals=HistoryDealsTotal();
      for(ulong i=0;i<deals;i++)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=symbol)
            continue;
         net+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
        }

      double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity<=0.0)
         equity=AccountInfoDouble(ACCOUNT_BALANCE);
      if(equity<=0.0)
         return(0.0);

      if(net>=0.0)
         return(0.0);

      double loss_percent=MathAbs(net)/equity*100.0;
      return(loss_percent);
     }
  }
#endif
