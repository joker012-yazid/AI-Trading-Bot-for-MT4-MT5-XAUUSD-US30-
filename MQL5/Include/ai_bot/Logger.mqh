#property strict

#ifndef __AI_LOGGER_MQH__
#define __AI_LOGGER_MQH__

class AILogger
  {
private:
   string m_symbol;
   string m_paths[3];
   int    m_price_digits;
   int    m_volume_digits;

   int OpenHandle()
     {
      int flags=FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE;
      for(int i=0;i<ArraySize(m_paths);i++)
        {
         int handle=FileOpen(m_paths[i],flags);
         if(handle==INVALID_HANDLE)
            continue;
         if(FileSize(handle)==0)
            FileWrite(handle,"timestamp","tz_offset","event","price","volume","profit","comment");
         FileSeek(handle,0,SEEK_END);
         return(handle);
        }
      return(INVALID_HANDLE);
     }

public:
   void Init(const string symbol)
     {
      m_symbol=symbol;
      m_price_digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
      if(m_price_digits<=0)
         m_price_digits=_Digits;
      m_volume_digits=(int)SymbolInfoInteger(symbol,SYMBOL_VOLUME_DIGITS);
      if(m_volume_digits<=0)
         m_volume_digits=2;

      m_paths[0]="Z:\\srv\\botdata\\logs\\"+symbol+"_trades.csv";
      m_paths[1]="/srv/botdata/logs/"+symbol+"_trades.csv";
      DirectoryCreate("logs");
      m_paths[2]="logs/"+symbol+"_trades.csv";
     }

   void Log(const string event_type,const double price,const double volume,const double profit,const string comment="")
     {
      datetime utc=TimeGMT();
      datetime server=TimeTradeServer();
      if(server==0)
         server=TimeCurrent();
      double offset=0.0;
      if(server>0)
         offset=(double)(server-utc)/3600.0;

      int handle=OpenHandle();
      if(handle==INVALID_HANDLE)
         return;

      MqlDateTime ts_struct;
      TimeToStruct(utc,ts_struct);
      string timestamp=StringFormat("%04d-%02d-%02dT%02d:%02d:%02dZ",
                                    ts_struct.year,
                                    ts_struct.mon,
                                    ts_struct.day,
                                    ts_struct.hour,
                                    ts_struct.min,
                                    ts_struct.sec);

      string offset_str=StringFormat("%+.2f",offset);

      FileWrite(handle,
                timestamp,
                offset_str,
                event_type,
                DoubleToString(price,m_price_digits),
                DoubleToString(volume,m_volume_digits),
                DoubleToString(profit,2),
                comment);
      FileClose(handle);
     }
  };
#endif
