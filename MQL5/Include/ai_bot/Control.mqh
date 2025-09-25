#property strict

#ifndef __AI_CONTROL_MQH__
#define __AI_CONTROL_MQH__

struct AIControl
  {
   bool   trading_enabled;
   double risk_percent;

   void Defaults()
     {
      trading_enabled=true;
      risk_percent=0.5;
     }
  };

namespace AIControlLoader
  {
   bool ReadFile(const string path,string &content)
     {
      int handle=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return(false);

      content="";
      while(!FileIsEnding(handle))
        {
         string line=FileReadString(handle);
         content+=line;
         if(!FileIsEnding(handle))
            content+="\n";
        }
      FileClose(handle);
      return(true);
     }

   string ExtractValue(const string text,const string key)
     {
      string token="\""+key+"\"";
      int pos=StringFind(text,token);
      if(pos<0)
         pos=StringFind(text,key);
      if(pos<0)
         return("");

      int colon=StringFind(text,":",pos);
      if(colon<0)
         return("");

      int i=colon+1;
      int length=(int)StringLen(text);
      while(i<length)
        {
         string ch=StringSubstr(text,i,1);
         if(ch==" " || ch=="\t" || ch=="\r" || ch=="\n")
           {
            i++;
            continue;
           }
         if(ch=="\"")
           {
            i++;
            string extracted="";
            while(i<length)
              {
               string c=StringSubstr(text,i,1);
               if(c=="\"")
                  break;
               extracted+=c;
               i++;
              }
            return(extracted);
           }

         string value="";
         while(i<length)
           {
            string c=StringSubstr(text,i,1);
            if(StringFind(" ,}\n\r\t",c)>=0)
               break;
            value+=c;
            i++;
           }
         return(value);
        }
      return("");
     }

   bool Load(AIControl &control)
     {
      control.Defaults();

      string paths[]={"Z:\\srv\\botdata\\control.json","/srv/botdata/control.json"};
      string content="";
      bool loaded=false;
      for(int i=0;i<ArraySize(paths);i++)
        {
         if(ReadFile(paths[i],content))
           {
            loaded=true;
            break;
           }
        }

      if(!loaded)
         return(true);

      string trading_token=ExtractValue(content,"trading_enabled");
      if(StringLen(trading_token)>0)
        {
         string lower=StringToLower(trading_token);
         if(lower=="true" || lower=="1" || lower=="yes")
            control.trading_enabled=true;
         else if(lower=="false" || lower=="0" || lower=="no")
            control.trading_enabled=false;
        }

      string risk_token=ExtractValue(content,"risk_percent");
      if(StringLen(risk_token)>0)
        {
         double value=StringToDouble(risk_token);
         if(value>0.0)
            control.risk_percent=value;
        }
      return(true);
     }
  }
#endif
