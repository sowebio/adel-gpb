------------------------------------------------------------------------------
--  ▖▖▄▖▄▖
--  ▌▌▄▌▛▌
--  ▚▘▙▖█▌
--
--  @file      gpb.adb
--  @copyright See authors list below and v20.copyrights file
--  @licence   GPL v3
--  @encoding  UTF-8
------------------------------------------------------------------------------
--  @summary
--  Network copy of the current binary project after build with bell(s)
--  From an idea of David Sauvage - david.sauvage@adalabs.com, author
--  of (among other) https://gitlab.com/adalabs/gnatgpr
--
--  @description
--
--  Ending a successful build with a sound. If the -XScp_Path=
--  parameter is set, copies the binary accordingly to the SCP destination path.
--  A second sound will be emitted after the end of the SCP copy (useful with
--  slow links).
--
--  Example of build string (with a ready SSH key):
--  %builder -Xaide_Build=Debug -XGpb_Scp=root@host.domain.tld:/usr/local/bin -d %eL -P%PP %config %autoconf %X -s
--
--  Which is translated as follows:
--  gprbuild -Xaide_Build=Debug -XGpb_Scp=root@host.domain.tld:/usr/local/bin -d -P/home/sr/Seafile/Sowebio/informatique/github/gpb/gpb.gpr -s
--
--  Extra option: -XGpb_Beep=off|ansi|[bell] ansi=console beep, bell=neat bell through pulseaudio (default).
--
--  HowTo
--  Rename ~/gnat-20xx/bin/gprbuild to gprbuild_exe
--  Copy ~/gpb/bin/gprbuild to ~/gnat-20xx/bin
--
--  Dependencies : gnatgpr (come as standard with AIDE), build reminder:
--  cd ~/opt/gnat-2021-downloads
--  git clone https://gitlab.com/adalabs/gnatgpr
--  cd gnatgpr
--  gprbuild -d -Pgnatgpr-bin.gpr -XLIBRARY_TYPE=static -XLANGKIT_SUPPORT_LIBRARY_TYPE=static \
--  -XLIBADALANG_LIBRARY_TYPE=static -XGPR_BUILD=static -XXMLADA_BUILD=static \
--  -XGNATCOLL_CORE_BUILD=static -XGNATCOLL_BUILD=static -XEnv=Production -s
--  cp binaries/gnatgpr ~/opt/gnat-2021/bin
--
--  @authors
--  David Sauvage - ds - david.sauvage@adalabs.com bash release (author)
--  Stéphane Rivière - sr - sriviere@soweb.io
--
--  @versions
--  20211213 - 0.1 - sr - initial release
--  20220422 - 0.2 - sr - add many checks and errors messages
--  20220609 - 0.3 - sr - add gprbuild_org and gnatgpr existence checks
--  20220716 - 0.4 - sr - fixes a division by zero time bug because the fiber
--                        speed is too fast here ;)
------------------------------------------------------------------------------

with Ada.Calendar;
with Ada.Command_Line;

with v20; use v20;
with v20.Fls;
with v20.Log;
with v20.Prg;
with v20.Tio;
with v20.Sys;
with v20.Vst; use v20.Vst;

procedure Gpb is

   package ACL renames Ada.Command_Line;

   Gprbuild_Parameters : VString := +"";
   Gprbuild_Project : VString := +"";
   Gprbuild_Gpb_Scp : VString := +"";
   Gprbuild_Gpb_Beep : VString := +"bell";
   Gprbuild_Binary_Orig : VString := +"";
   Gprbuild_Binary_Dest : VString := +"";
   Gprbuild_Time : Natural := 0;

   SE_Result : Integer := 0;

   Start_Time_SCP : Ada.Calendar.Time;

   procedure Beep_Console is
   begin
      if (Gprbuild_Gpb_Beep = "ansi") then
         Tio.Beep;
      elsif (Gprbuild_Gpb_Beep = "bell") then
         -- Pulseaudio paplay & freedesktop sounds come as standard on Ubuntu 18.04 LTS and 22.04 LTS
         Sys.Shell_Execute ( +"paplay /usr/share/sounds/freedesktop/stereo/complete.oga");
      end if;
   end Beep_Console;

begin

   Sys.Set_Memory_Monitor (True);

   Prg.Set_Version (0, 4);
   Log.Set_Display(True);

   Log.Line;
   Log.Msg (+"Gprbuild stub for GnatStudio");
   Log.Msg (+"Copyright (C) Sowebio SARL 2020-2022, according to GPLv3.");
   Log.Msg (Prg.Get_Version & " - " & v20.Get_Version & " - " & v20.Get_Build);
   Log.Line;

   ----------------------------------------------------------------------------
   --  Get parameters, extract and/or remove some specials ones
   ----------------------------------------------------------------------------

   for A in 1 .. ACL.Argument_Count loop
      if (Vst.Index ( To_VString (ACL.Argument (A)), +"-P") = 1) then
         Gprbuild_Project := Slice ( To_VString (ACL.Argument (A)), 3, Vst.Length (To_VString (ACL.Argument (A))) );
         Gprbuild_Parameters := Gprbuild_Parameters & ACL.Argument (A) & " ";
      elsif (Vst.Index ( To_VString (ACL.Argument (A)), +"-XGpb_Scp=") = 1) then
         Gprbuild_Gpb_Scp := Slice ( To_VString (ACL.Argument (A)), 11, Vst.Length (To_VString (ACL.Argument (A))) );
      elsif (Vst.Index ( To_VString (ACL.Argument (A)), +"-XGpb_Beep=") = 1) then
         Gprbuild_Gpb_Beep := Slice ( To_VString (ACL.Argument (A)), 12, Vst.Length (To_VString (ACL.Argument (A))) );
      else
         Gprbuild_Parameters := Gprbuild_Parameters & ACL.Argument (A) & " ";
      end if;
   end loop;

   Log.Set_Debug (True);

   Log.Msg ("Gprbuild_Parameters: " & Gprbuild_Parameters);
   Log.Msg ("Gprbuild_Project: " & Gprbuild_Project);
   Log.Msg ("Gprbuild_Gpb_Scp: " & Gprbuild_Gpb_Scp);
   Log.Msg ("Gprbuild_Gpb_Beep: " & Gprbuild_Gpb_Beep);
   Log.Line;

   ----------------------------------------------------------------------------
   --  Build binary by calling the real gprbuild
   ----------------------------------------------------------------------------

   if Sys.Is_Command (+"gprbuild_org") then

      Sys.Shell_Execute (Sys.Command_Path (+"gprbuild_org") & " " & Gprbuild_Parameters, SE_Result);
      if SE_Result = 0 then

         Beep_Console;

         if not ((Index ( Gprbuild_Parameters, "-c") > 0) or
                   (Index ( Gprbuild_Parameters, "-u") > 0)) then

            if Sys.Is_Command (+"gnatgpr") then

               -- Get path of builded binary
               Sys.Shell_Execute (Sys.Command_Path (+"gnatgpr") & " -b " & Gprbuild_Project, SE_Result, Gprbuild_Binary_Orig);
               if SE_Result = 0 then

                  if not Empty (Gprbuild_Binary_Orig) then

                     Log.Line;
                     Log.Msg ("Gprbuild_Binary_Orig: " & Gprbuild_Binary_Orig);

                     if not  Empty (Gprbuild_Gpb_Scp) then

                        Gprbuild_Binary_Dest := Gprbuild_Gpb_Scp & "/" & Tail_After_Match (Gprbuild_Binary_Orig, '/');
                        Log.Msg ("Gprbuild_Binary_Dest: " & Gprbuild_Binary_Dest);
                        Log.Line;

   ----------------------------------------------------------------------------
   --  Scp copy if needed
   ----------------------------------------------------------------------------

                        Log.Msg ("SCP copy (" & To_VString (Fls.File_Size (Gprbuild_Binary_Orig)/1000) & "Kb) in progress...");
                        Start_Time_SCP := Ada.Calendar.Clock;

                        Sys.Shell_Execute ("scp -q " & Gprbuild_Binary_Orig & " " & Gprbuild_Gpb_Scp, SE_Result);
                        if SE_Result = 0 then

                           --  Division by zero protection when FTTx is too fast :)
                           Gprbuild_Time := Prg.Duration_Stamp_Seconds (Start_Time_SCP);
                           Gprbuild_Time := (if Gprbuild_Time > 0 then Gprbuild_Time else 1);

                           Log.Msg ("SCP copy (" & To_VString (Prg.Duration_Stamp_Seconds (Start_Time_SCP)) & "s @ " &
                                      To_VString ((Fls.File_Size (Gprbuild_Binary_Orig) / Gprbuild_Time)/1000) &
                                      "Kbps) successful.");
                           Beep_Console;
                        else
                           Log.Err ("Error: scp copy not successful (code=" & Trim_Left (To_VString (SE_Result)) & ")");
                        end if;
                     end if;
                  end if;
               else
                  Log.Line;
                  Log.Err ("Error: gnatgpr command not successful (code=" & Trim_Left (To_VString (SE_Result)) & ")");
                  Log.Err ("gnatgpr command: " & Sys.Command_Path (+"gnatgpr") & " -b " & Gprbuild_Project);
                  --Log.Err ("gnatgpr output: " & Gprbuild_Binary_Orig);
               end if;
            else
               Log.Line;
               Log.Err ("Error: gnatgpr not found");
            end if;
         end if;
      else
         Log.Line;
         Log.Err ("Error: gprbuild_org command not successful");
      end if;
   else
      Log.Line;
      Log.Err ("Error: gprbuild_org not found");
   end if;

   Log.Line;

exception

   --  Runtime errors
   when Error : others =>
      v20.Exception_Handling (Error);

-----------------------------------------------------------------------------
end Gpb;
-----------------------------------------------------------------------------
