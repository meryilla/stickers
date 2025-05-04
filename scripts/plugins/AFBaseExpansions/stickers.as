/* Stickers AFBase Expansion Script
By Meryilla

Allows players to send animated sprites to the HUD of other players. As cancerous as it sounds.

Much of the menu logic was borrowed from Zode's AFB Menu.
*/

Stickers stickers;

void Stickers_Call()
{
	stickers.RegisterExpansion( stickers );
}

class Stickers : AFBaseClass
{
	void ExpansionInfo()
	{
		this.AuthorName = "Meryilla";
		this.ExpansionName = "Stickers";
		this.ShortName = "STICKERS";
	}

	void ExpansionInit()
	{
		RegisterCommand( "say stickers", "", "- send animated sprites to other players!", ACCESS_Z, @Stickers::PopMenu, CMD_SUPRESS );	
	}

	void MapInit()
	{
		Stickers::g_stickerSprites.deleteAll();
		Stickers::g_stickerCooldowns.deleteAll();
		Stickers::g_commandCooldowns.deleteAll();
		Stickers::ReadStickers();
		array<string> stickerNames = Stickers::g_stickerSprites.getKeys();

		for( uint i = 0; i < stickerNames.length(); i++ )
		{
			Stickers::StickerData@ hData = cast<Stickers::StickerData@>( Stickers::g_stickerSprites[stickerNames[i]] );
			g_Game.PrecacheModel( "sprites/"+hData.szSpritePath+".spr" );
			if( !hData.szSoundPath.IsEmpty() )
				g_SoundSystem.PrecacheSound( hData.szSoundPath );
		}
		Stickers::MenuInit();
	}
}

namespace Stickers
{
	const float g_flStickerDelay = 10.0; //Default delay between stickers. Should be larger than the default hold time
	const float g_flDefaultHoldTime = 8; //Default hold time

	string g_stickersFile = "scripts/plugins/AFBaseExpansions/stickersprites.txt";
	dictionary g_stickerSprites;
	dictionary g_commandCooldowns;
	dictionary g_stickerCooldowns;
	CTextMenu@ stickerMenu = null;

	enum MENU_STATUS
	{
		MENU_INIT = 0,
		MENU_PLAYER,
		MENU_SPRITE,
		MENU_REMOVE,
		MENU_MAIN
	}

	class StickerData
	{
		string szSpritePath;
		string szName;
		int iFrames;
		float flFrameRate;
		float flHoldTime;
		string szSoundPath;
	}

	class PlayerMenu
	{
		CTextMenu@ cMenu;
		int iState;
		string sTarget;
	}

	class PlayerState
	{
		bool blEnabled = true;
	}

	dictionary g_playerStates;

	dictionary g_playerMenus;
	const int iMenuTime = 10;

	PlayerState@ GetState( EHandle hPlayer )
	{
		PlayerState pState;
		if( !hPlayer )
			return pState;

		CBasePlayer@ pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
		string szFixId = AFBase::FormatSafe( AFBase::GetFixedSteamID( pPlayer ) );
		

		if( !g_playerStates.exists( szFixId ) )
		{
			g_playerStates[szFixId] = pState;
		}
		return cast<PlayerState@>( g_playerStates[szFixId] );
	}

	void MenuInit()
	{
		if( g_playerMenus.getSize() <= 0 )
		{
			PlayerMenu plrMenu;
			@plrMenu.cMenu = null;
			plrMenu.iState = MENU_INIT;
			plrMenu.sTarget = "nonexistantuser";

			for( int i = 1; i <= g_Engine.maxClients; i++ )
				g_playerMenus[i] = plrMenu;
		}
		else
		{
			for( int i = 1; i <= g_Engine.maxClients; i++ )
				MenuRemove(i);
		}
	}

	void ReadStickers()
	{
		File@ file = g_FileSystem.OpenFile( g_stickersFile, OpenFile::READ );

		if( file !is null && file.IsOpen() )
		{
			while( !file.EOFReached() )
			{
				string szLine;
				file.ReadLine( szLine );
				//fix for linux
				string sFix = szLine.SubString( szLine.Length() -1, 1 );

				if( sFix == " " || sFix == "\n" || sFix == "\r" || sFix == "\t" )
					szLine = szLine.SubString( 0, szLine.Length() -1 );

				if( szLine.SubString( 0, 1 ) == "#" || szLine.IsEmpty() )
					continue;

				array<string> parsed;// = szLine.Split( " " );
				array<string> splitLine = szLine.Split( " " );
				for( uint i = 0; i < splitLine.length(); i++ )
				{
					parsed.insertLast( splitLine[i] );
				}

				if( parsed.length() < 2 )
					continue;

				StickerData hData;
				string szName = "";
				string szSpritePath = "";
				int iFrames = 0;
				float flFrameRate = 10;
				float flHoldTime = g_flDefaultHoldTime;
				string szSoundPath = "";

				array<string> parsed2 = parsed[0].Split( "/" );
				szName = parsed2[parsed2.length() -1];
				szName = szName.ToLowercase();
				szSpritePath = parsed[0];
				iFrames = atoi( parsed[1] );
				flFrameRate = atof( parsed[2] );

				if( parsed.length() >= 4 )
					flHoldTime = atof( parsed[3] );
				if( parsed.length() >= 4 )
					szSoundPath = parsed[4];

				if( szName == "" || szSpritePath == "" )
					continue;

				hData.szName = szName;
				hData.szSpritePath = szSpritePath;
				hData.iFrames = iFrames;
				hData.flFrameRate = flFrameRate;
				hData.flHoldTime = flHoldTime;
				hData.szSoundPath = szSoundPath;

				g_stickerSprites[szName] = hData;
			}
			file.Close();
		}
	}

	void MenuPartialRemove( int i )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[i] );

		if( @plrMenu.cMenu !is null )
			plrMenu.cMenu.Unregister();

		@plrMenu.cMenu = null;
	}

	void MenuRemove( int i )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[i] );

		if( @plrMenu.cMenu !is null )
			plrMenu.cMenu.Unregister();

		@plrMenu.cMenu = null;
		plrMenu.iState = MENU_INIT;
		plrMenu.sTarget = "nonexistantuser";
	}

	void PopMenu( AFBaseArguments@ AFArgs )
	{
		CBasePlayer@ pPlayer = AFArgs.User;
		string szFixId = AFBase::FormatSafe( AFBase::GetFixedSteamID( pPlayer ) );

		if( g_commandCooldowns.exists( szFixId ) && float( g_commandCooldowns[szFixId] ) > g_Engine.time )
		{
			stickers.Tell( "Don't spam the command.", pPlayer, HUD_PRINTTALK );
			return;
		}
		else
			g_commandCooldowns[szFixId] = g_Engine.time + 2.0f;

		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[AFArgs.User.entindex()] );

		if( plrMenu.iState != MENU_REMOVE )
		{
			MenuRemove( AFArgs.User.entindex() );
			//MakePlayerMenu( AFArgs.User.entindex() );
			MakeMainMenu( AFArgs.User.entindex() );
			plrMenu.cMenu.Open( iMenuTime,0,AFArgs.User );
		}
	}

	void MakeMainMenu( int iPlayerIndex )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[iPlayerIndex] );
		@plrMenu.cMenu = CTextMenu( Stickers::MenuCallback );
		plrMenu.cMenu.SetTitle( "\\r[Stickers]\\w Select option: \\w" );
		plrMenu.cMenu.AddItem( "Send Sticker", null );
		plrMenu.cMenu.AddItem( "Enable/Disable Stickers", null );

		plrMenu.cMenu.Register();
		plrMenu.iState = MENU_MAIN;
	}

	//Construct player list on menu
	void MakePlayerMenu( int i )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[i] );

		@plrMenu.cMenu = CTextMenu( Stickers::MenuCallback );
		plrMenu.cMenu.SetTitle( "\\r[Stickers]\\w Select target: \\w" );
		CBasePlayer@ pSearch = null;

		for( int j = 1; j <= g_Engine.maxClients; j++ )
		{
			@pSearch = g_PlayerFuncs.FindPlayerByIndex( j );
			if( pSearch !is null )
				plrMenu.cMenu.AddItem( pSearch.pev.netname, any( AFBase::FormatSafe( AFBase::GetFixedSteamID( pSearch ) ) ) );
		}

		plrMenu.cMenu.Register();
		plrMenu.iState = MENU_PLAYER;
	}

	void MenuCallback( CTextMenu@ mMenu, CBasePlayer@ pPlayer, int iPage, const CTextMenuItem@ mItem )
	{
		if( mItem !is null && pPlayer !is null )
		{
			PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[pPlayer.entindex()] );
			if( plrMenu.iState == MENU_MAIN )
			{
				if( mItem.m_szName == "Send Sticker" )
				{
					g_Scheduler.SetTimeout( "DelayedCallback", 0.1f, EHandle( pPlayer ), 0 );
				}
				else if( mItem.m_szName == "Enable/Disable Stickers" )
				{
					g_Scheduler.SetTimeout( "DelayedCallback", 0.1f, EHandle( pPlayer ), 1 );
				}

				return;
			}
			else if( plrMenu.iState == MENU_PLAYER )
			{
				string temp = "";
				if( !mItem.m_pUserData.retrieve( temp ) )
				{
					stickers.Tell( "Failed to retrieve menu data!", pPlayer, HUD_PRINTTALK );

					return;
				}

				plrMenu.sTarget = temp;

				g_Scheduler.SetTimeout( "DelayedCallback", 0.1f, EHandle( pPlayer ), 0 );

				return;
			}
			else if( plrMenu.iState == MENU_SPRITE )
			{
				plrMenu.iState = MENU_REMOVE;
				ExecuteSpriteCommand( mItem, pPlayer );

				g_Scheduler.SetTimeout( "MenuRemove", 0.1f, pPlayer.entindex() );

				return;
			}
			stickers.Tell( "Unknown menu state!", pPlayer, HUD_PRINTTALK );
		}
	}

	void DelayedCallback( EHandle ePlayer, int iOption=0 )
	{
		CBaseEntity@ pEnt = ePlayer;
		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pEnt );
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[pPlayer.entindex()] );
		if( plrMenu.iState == MENU_MAIN )
		{
			MenuPartialRemove( pPlayer.entindex() );
			if( iOption == 1 )
			{
				PlayerState@ pState = GetState( pPlayer );
				if( pState.blEnabled )
				{
					pState.blEnabled = false;
					stickers.Tell( "You will no longer be able to send or receive stickers.", pPlayer, HUD_PRINTTALK );
				}
				else
				{
					pState.blEnabled = true;
					stickers.Tell( "You can now send or receive stickers.", pPlayer, HUD_PRINTTALK );
				}
			}
			else
			{
				MakePlayerMenu( pPlayer.entindex() );
				plrMenu.cMenu.Open( iMenuTime,0,pPlayer );
			}
		}
		else if( plrMenu.iState == MENU_PLAYER )
		{
			MenuPartialRemove( pPlayer.entindex() );
			MakeSpriteMenu( pPlayer.entindex() );
			plrMenu.cMenu.Open( iMenuTime,0,pPlayer );
		}
	}

	//Construct sprite list on menu
	void MakeSpriteMenu( int iPlayerIndex )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[iPlayerIndex] );
		@plrMenu.cMenu = CTextMenu( Stickers::MenuCallback );
		plrMenu.cMenu.SetTitle( "\\r[Stickers]\\w Select sprite:" );

		array<string> stickerNames = g_stickerSprites.getKeys();
		stickerNames.sortAsc();
		for( uint i = 0; i < stickerNames.length(); i++ )
		{
			plrMenu.cMenu.AddItem( stickerNames[i].ToLowercase(), null );
		}

		plrMenu.cMenu.Register();
		plrMenu.iState = MENU_SPRITE;
	}

	//Determine if target is valid
	void ExecuteSpriteCommand( const CTextMenuItem@ mItem, CBasePlayer@ pPlayer )
	{
		PlayerMenu@ plrMenu = cast<PlayerMenu@>( g_playerMenus[pPlayer.entindex()] );
		CBasePlayer@ pTarget;
		if( plrMenu.sTarget != "nonexistantuser" )
		{
			if( !mItem.m_szName.IsEmpty() )
			{
				string szFixId;
				for( int i = 1; i <= g_Engine.maxClients; i++ )
				{
					@pTarget = g_PlayerFuncs.FindPlayerByIndex( i );
					if( pTarget !is null && pTarget.IsConnected() )
					{
						szFixId = AFBase::FormatSafe( AFBase::GetFixedSteamID( pTarget ) );
						if( string( plrMenu.sTarget ).ToLowercase() == string( pTarget.pev.netname ).ToLowercase() || string( plrMenu.sTarget ) == szFixId )
							break;
					}
				}
				if( pTarget is null )
				{
					stickers.Tell( "Oops, can't find them. Maybe try again?", pPlayer, HUD_PRINTTALK );
					return;
				}
				PlayerState@ pSenderState = GetState( pPlayer );
				PlayerState@ pTargetState = GetState( pTarget );

				if( !pSenderState.blEnabled )
				{
					stickers.Tell( "You can't send stickers if you have disabled them.", pPlayer, HUD_PRINTTALK);
					return;
				}
				else if( !pTargetState.blEnabled )
				{
					stickers.Tell( "" + pTarget.pev.netname + " has disabled stickers :(", pPlayer, HUD_PRINTTALK);
					return;
				}

				if( float( g_stickerCooldowns[szFixId] ) > g_Engine.time )
				{
					stickers.Tell("Please wait, " + pTarget.pev.netname + " has recently received a sticker!", pPlayer, HUD_PRINTTALK);
					return;
				}

				StickerData@ hData = cast<StickerData@>( g_stickerSprites[mItem.m_szName] );
				if( !hData.szSoundPath.IsEmpty() )
					PlaySprite( pTarget, mItem.m_szName, true, hData.flHoldTime );
				else
					PlaySprite( pTarget, mItem.m_szName, false, hData.flHoldTime );
				stickers.Tell( "" + pPlayer.pev.netname + " sent you a sticker!", pTarget, HUD_PRINTTALK );
			}

			return;
		}

		stickers.Tell( "Illegal target!", pPlayer, HUD_PRINTTALK );
	}

	//Display the sprite on the relevant player's screen
	void PlaySprite( EHandle hPlayer, string szStickerName, bool blSound = false, float flHoldTime = g_flDefaultHoldTime )
	{
		if( !hPlayer )
			return;

		CBasePlayer @pPlayer = cast<CBasePlayer@>( hPlayer.GetEntity() );
		RGBA RGBA_STICKER = RGBA( 255, 255, 255, 255 );

		StickerData@ hData = cast<StickerData@>( g_stickerSprites[szStickerName] );

		HUDSpriteParams StickerDisplayParams;
		StickerDisplayParams.channel = 0;
		StickerDisplayParams.flags = HUD_ELEM_SCR_CENTER_X | HUD_ELEM_SCR_CENTER_Y | HUD_ELEM_NO_BORDER | HUD_SPR_OPAQUE;
		StickerDisplayParams.x = -0.2; //X axis position of the sprite on the HUD
		StickerDisplayParams.y = -0.1; //Y axis position of the sprite on the HUD
		StickerDisplayParams.spritename = hData.szSpritePath+".spr";
		StickerDisplayParams.color1 = RGBA_STICKER;
		StickerDisplayParams.color2 = RGBA_STICKER;
		StickerDisplayParams.frame = 0;
		StickerDisplayParams.numframes = hData.iFrames;
		StickerDisplayParams.framerate = hData.flFrameRate;
		StickerDisplayParams.fxTime = flHoldTime;
		StickerDisplayParams.holdTime = flHoldTime; //How long the sprite is displayed for

		g_PlayerFuncs.HudCustomSprite( pPlayer, StickerDisplayParams );
		string szFixId = AFBase::FormatSafe( AFBase::GetFixedSteamID( pPlayer ) );
		//Cooldown should be a little lower if the sticker duration is short
		g_stickerCooldowns[szFixId] = g_Engine.time + Math.max( g_flStickerDelay, hData.flHoldTime + 1 );


		if( blSound )
		{
			g_SoundSystem.PlaySound( pPlayer.edict(), CHAN_STREAM, hData.szSoundPath, VOL_NORM, ATTN_NORM, 0, PITCH_NORM, pPlayer.entindex(), true, pPlayer.GetOrigin() );
		}
	}
}
