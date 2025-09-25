#property copyright "AI Trading Bot"
#property strict

#ifndef __AI_INDICATORS_MQH__
#define __AI_INDICATORS_MQH__

namespace AIIndicators
  {
   bool GetEMA(const string symbol,const ENUM_TIMEFRAMES timeframe,const int period,const int shift,double &value)
     {
      int handle=iMA(symbol,timeframe,period,0,MODE_EMA,PRICE_CLOSE);
      if(handle==INVALID_HANDLE)
         return(false);

      double buffer[];
      if(CopyBuffer(handle,0,shift,1,buffer)!=1)
        {
         IndicatorRelease(handle);
         return(false);
        }

      value=buffer[0];
      IndicatorRelease(handle);
      return(true);
     }

   bool GetATR(const string symbol,const ENUM_TIMEFRAMES timeframe,const int period,const int shift,double &value)
     {
      int handle=iATR(symbol,timeframe,period);
      if(handle==INVALID_HANDLE)
         return(false);

      double buffer[];
      if(CopyBuffer(handle,0,shift,1,buffer)!=1)
        {
         IndicatorRelease(handle);
         return(false);
        }

      value=buffer[0];
      IndicatorRelease(handle);
      return(true);
     }
  }
#endif
