//
//  OSXObjcWrapper.cpp
//  GacTest
//
//  Created by Robert Bu on 12/2/14.
//  Copyright (c) 2014 Robert Bu. All rights reserved.
//

#include "CocoaWindow.h"

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

// _NSGetProgname
#import <crt_externs.h>

#include "CocoaHelper.h"
#include "ServicesImpl/CocoaResourceService.h"

using namespace vl::presentation;

@interface CocoaWindowDelegate : NSObject<NSWindowDelegate>

@property (nonatomic, readonly) INativeWindow::WindowSizeState sizeState;
@property (assign) INativeWindow* nativeWindow;

- (id)initWithNativeWindow:(INativeWindow*)window;

@end

namespace vl {
    
    namespace presentation {
        
        namespace osx {
            
            CocoaWindow::CocoaWindow():
                nativeContainer(0),
                parentWindow(0),
                alwaysPassFocusToParent(false),
                mouseLastX(0),
                mouseLastY(0),
                mouseHoving(false),
                graphicsHandler(0),
                customFrameMode(false),
                supressingAlt(false),
                enabled(false)
            {
                _CreateWindow();
            }
            
            CocoaWindow::~CocoaWindow()
            {
                if(nativeContainer)
                {
                    [nativeContainer->window close];
                    delete nativeContainer;
                }
            }
            
            void CocoaWindow::_CreateWindow()
            {
                NSUInteger windowStyle = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
                
                NSRect windowRect = NSMakeRect(0, 0, 0, 0);
                
                NSWindow* window = [[NSWindow alloc] initWithContentRect:windowRect
                                                               styleMask:windowStyle
                                                                 backing:NSBackingStoreBuffered
                                                                   defer:NO];
                NSWindowController* controller = [[NSWindowController alloc] initWithWindow:window];
                [window orderFrontRegardless];
                
                [window setAcceptsMouseMovedEvents:YES];
                [window setLevel:NSMainMenuWindowLevel + 1];
                
                // hide on diactivate
                [window setHidesOnDeactivate:YES];
                
                // disable auto restore...
                // which actually sucks for our usage
                [window setRestorable:NO];
                
                nativeContainer = new NSContainer();
                nativeContainer->window = window;
                nativeContainer->controller = controller;
                
                nativeContainer->delegate = [[CocoaWindowDelegate alloc] initWithNativeWindow:this];
                [window setDelegate:nativeContainer->delegate];
                
                currentCursor = GetCurrentController()->ResourceService()->GetDefaultSystemCursor();
            }

            Rect CocoaWindow::GetBounds()
            {
                NSRect nsbounds = [nativeContainer->window frame];
                
                // frame.origin is lower-left
                return Rect(nsbounds.origin.x,
                            nsbounds.origin.y - nsbounds.size.height,
                            nsbounds.size.width + nsbounds.origin.x,
                            nsbounds.origin.y);
            }

            void CocoaWindow::SetBounds(const Rect& bounds) 
            {
                Rect newBounds = bounds;
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->Moving(newBounds, true);
                }
                NSRect nsbounds = NSMakeRect(newBounds.Left(),
                                             newBounds.Bottom(),
                                             newBounds.Width(),
                                             newBounds.Height());
                [nativeContainer->window setFrame:nsbounds display:YES];
                

                //Show();
            }

            Size CocoaWindow::GetClientSize() 
            {
                return GetClientBoundsInScreen().GetSize();
            }

            void CocoaWindow::SetClientSize(Size size) 
            {   [nativeContainer->window setContentSize:NSMakeSize(size.x, size.y)];
                [nativeContainer->window display];
            }

            Rect CocoaWindow::GetClientBoundsInScreen() 
            {
                NSRect nsbounds = [nativeContainer->window frame];
                NSRect contentFrame = [nativeContainer->window contentRectForFrameRect:[nativeContainer->window frame]];
                return Rect(nsbounds.origin.x + contentFrame.origin.x,
                            nsbounds.origin.y - contentFrame.size.height + contentFrame.origin.y,
                            nsbounds.origin.x + contentFrame.size.width + contentFrame.origin.x,
                            nsbounds.origin.y + contentFrame.origin.y);
            }

            WString CocoaWindow::GetTitle() 
            {
                NSString* title = [nativeContainer->window title];
                return NSStringToWString(title);
            }

            void CocoaWindow::SetTitle(WString title) 
            {
                [nativeContainer->window setTitle:WStringToNSString(title)];
            }

            INativeCursor* CocoaWindow::GetWindowCursor() 
            {
                return currentCursor;
            }

            void CocoaWindow::SetWindowCursor(INativeCursor* cursor) 
            {
                currentCursor = cursor;
                
                dynamic_cast<CocoaCursor*>(cursor)->Set();
                
                [nativeContainer->window invalidateCursorRectsForView:nativeContainer->window.contentView];
            }

            Point CocoaWindow::GetCaretPoint()
            {
                return caretPoint;
            }
            
            void CocoaWindow::SetCaretPoint(Point point)
            {
                caretPoint = point;
                // todo
                
            }

            INativeWindow* CocoaWindow::GetParent() 
            {
                return parentWindow;
            }

            void CocoaWindow::SetParent(INativeWindow* parent) 
            {
                parentWindow = dynamic_cast<CocoaWindow*>(parent);
                if(parentWindow)
                {
                    [nativeContainer->window setParentWindow:0];
                }
                else
                {
                    [nativeContainer->window setParentWindow:parentWindow->GetNativeContainer()->window];
                }
            }

            bool CocoaWindow::GetAlwaysPassFocusToParent() 
            {
                return alwaysPassFocusToParent;
            }

            void CocoaWindow::SetAlwaysPassFocusToParent(bool value) 
            {
                alwaysPassFocusToParent = value;
            }

            void CocoaWindow::EnableCustomFrameMode() 
            {
                customFrameMode = true;
            }

            void CocoaWindow::DisableCustomFrameMode() 
            {
                customFrameMode = false;
            }

            bool CocoaWindow::IsCustomFrameModeEnabled() 
            {
                return customFrameMode;
            }

            INativeWindow::WindowSizeState CocoaWindow::GetSizeState()
            {
                CocoaWindowDelegate* delegate = (CocoaWindowDelegate*)[nativeContainer->window delegate];
                return [delegate sizeState];
            }

            void CocoaWindow::Show() 
            {
                [nativeContainer->window makeKeyAndOrderFront:nil];
            }

            void CocoaWindow::ShowDeactivated() 
            {
                [nativeContainer->window orderOut:nil];
            }

            void CocoaWindow::ShowRestored() 
            {
                // todo
            }

            void CocoaWindow::ShowMaximized() 
            {
                // todo
                [nativeContainer->window toggleFullScreen:nil];
            }

            void CocoaWindow::ShowMinimized() 
            {
                [nativeContainer->window miniaturize:nil];
            }

            void CocoaWindow::Hide() 
            {
                // HidesOnDeactivate
                [nativeContainer->window orderOut:nil];
            }

            bool CocoaWindow::IsVisible() 
            {
                return [nativeContainer->window isVisible];
            }

            void CocoaWindow::Enable() 
            {
                // todo
                [nativeContainer->window makeKeyWindow];
                [nativeContainer->window makeFirstResponder:nativeContainer->window];
                enabled = true;
            }

            void CocoaWindow::Disable() 
            {
                // todo
                [nativeContainer->window orderOut:nil];
                [nativeContainer->window makeFirstResponder:nil];
                enabled = false;
            }

            bool CocoaWindow::IsEnabled() 
            {
                return enabled;
            }

            void CocoaWindow::SetFocus() 
            {
                [nativeContainer->window makeKeyWindow];
            }

            bool CocoaWindow::IsFocused() 
            {
                return [nativeContainer->window isKeyWindow];
            }

            void CocoaWindow::SetActivate() 
            {
                [nativeContainer->window makeKeyAndOrderFront:nil];
            }

            bool CocoaWindow::IsActivated() 
            {
                // todo
                return [nativeContainer->window isKeyWindow];
            }

            void CocoaWindow::ShowInTaskBar() 
            {
                // not configurable at runtime
            }

            void CocoaWindow::HideInTaskBar() 
            {
                // not configurable at runtime
            }

            bool CocoaWindow::IsAppearedInTaskBar() 
            {
                return true;
            }

            void CocoaWindow::EnableActivate() 
            {
                // not configurable
            }

            void CocoaWindow::DisableActivate() 
            {
                // not configurable
            }

            bool CocoaWindow::IsEnabledActivate() 
            {
                return true;
            }
            
            bool CocoaWindow::RequireCapture() 
            {
                return true;
            }

            bool CocoaWindow::ReleaseCapture() 
            {
                return true;
            }

            bool CocoaWindow::IsCapturing() 
            {
                return true;
            }

            bool CocoaWindow::GetMaximizedBox() 
            {
                NSWindowCollectionBehavior behavior = [nativeContainer->window collectionBehavior];
                return behavior & NSWindowCollectionBehaviorFullScreenPrimary;
            }

            void CocoaWindow::SetMaximizedBox(bool visible) 
            {
                NSWindowCollectionBehavior behavior = [nativeContainer->window collectionBehavior];
                if(visible)
                    behavior |= NSWindowCollectionBehaviorFullScreenPrimary;
                else
                    behavior ^= NSWindowCollectionBehaviorFullScreenPrimary;
                [nativeContainer->window setCollectionBehavior:behavior];
            }

            bool CocoaWindow::GetMinimizedBox() 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                return styleMask & NSMiniaturizableWindowMask;
            }

            void CocoaWindow::SetMinimizedBox(bool visible) 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                if(visible)
                    styleMask |= NSMiniaturizableWindowMask;
                else
                    styleMask ^= NSMiniaturizableWindowMask;
                [nativeContainer->window setStyleMask:styleMask];
            }

            bool CocoaWindow::GetBorder() 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                return !(styleMask & NSBorderlessWindowMask);
            }

            void CocoaWindow::SetBorder(bool visible) 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                if(visible)
                    styleMask |= NSBorderlessWindowMask;
                else
                    styleMask ^= NSBorderlessWindowMask;
                [nativeContainer->window setStyleMask:styleMask];
            }

            bool CocoaWindow::GetSizeBox() 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                return styleMask & NSResizableWindowMask;
            }

            void CocoaWindow::SetSizeBox(bool visible) 
            {
                NSUInteger styleMask = [nativeContainer->window styleMask];
                if(visible)
                    styleMask |= NSResizableWindowMask;
                else
                    styleMask ^= NSResizableWindowMask;
                [nativeContainer->window setStyleMask:styleMask];
            }

            bool CocoaWindow::GetIconVisible() 
            {
                // no such thing
                return false;
            }

            void CocoaWindow::SetIconVisible(bool visible) 
            {
                (void)visible;
            }

            bool CocoaWindow::GetTitleBar() 
            {
                return GetBorder();
            }

            void CocoaWindow::SetTitleBar(bool visible) 
            {
                SetBorder(visible);
            }

            bool CocoaWindow::GetTopMost() 
            {
                return [nativeContainer->window isKeyWindow];
            }

            void CocoaWindow::SetTopMost(bool topmost) 
            {
                [nativeContainer->window makeKeyAndOrderFront:nil];
            }

            void CocoaWindow::SupressAlt()
            {
                
            }

            bool CocoaWindow::InstallListener(INativeWindowListener* listener) 
            {
                if(listeners.Contains(listener))
                {
                    return false;
                }
                else
                {
                    listeners.Add(listener);
                    return true;
                }
            }

            bool CocoaWindow::UninstallListener(INativeWindowListener* listener) 
            {
                if(listeners.Contains(listener))
                {
                    listeners.Remove(listener);
                    return true;
                }
                else
                {
                    return false;
                }
            }
            
            void CocoaWindow::RedrawContent() 
            {
                [nativeContainer->window.contentView setNeedsDisplay:YES];
                [nativeContainer->window display];
            }

            NSContainer* CocoaWindow::GetNativeContainer() const
            {
                return nativeContainer;
            }
            
            void CocoaWindow::SetGraphicsHandler(Interface* handler)
            {
                graphicsHandler = handler;
            }
            
            Interface* CocoaWindow::GetGraphicsHandler() const
            {
                return graphicsHandler;
            }
            
            void CocoaWindow::InvokeMoved()
            {
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->Moved();
                }
            }

            bool CocoaWindow::InvokeClosing()
            {
                bool cancel = false;
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->Closing(cancel);
                }
                return cancel;
            }
            
            void CocoaWindow::InvokeAcivate()
            {
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->Activated();
                }
            }
            
            void CocoaWindow::InvokeDeactivate()
            {
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->Deactivated();
                }
            }
            
            void CocoaWindow::InvokeGotFocus()
            {
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->GotFocus();
                }
            }
            
            void CocoaWindow::InvokeLostFocus()
            {
                for(vint i=0; i<listeners.Count(); ++i)
                {
                    listeners[i]->LostFocus();
                }
            }
            
            NSContainer* GetNSNativeContainer(INativeWindow* window)
            {
                return (dynamic_cast<CocoaWindow*>(window))->GetNativeContainer();
            }
            
            NativeWindowMouseInfo CreateMouseInfo(NSWindow* window, NSEvent* event)
            {
                NativeWindowMouseInfo info;
                
                if(event.type == NSScrollWheel && [event respondsToSelector:@selector(scrollingDeltaY)])
                {
                    double deltaY;
                    
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1070
                    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
                    {
                        deltaY = [event scrollingDeltaY];
                        
                        if ([event hasPreciseScrollingDeltas])
                        {
                            deltaY *= 0.1;
                        }
                    }
                    else
#endif /*MAC_OS_X_VERSION_MAX_ALLOWED*/
                    {
                        deltaY = [event deltaY];
                    }
                    
                    info.wheel = (int)deltaY;
                }
                
                info.left = event.type == NSLeftMouseDown;
                info.right = event.type == NSRightMouseDown;
                // assuming its middle mouse
                info.middle = (event.type == NSOtherMouseDown);
                
                info.ctrl = event.modifierFlags & NSControlKeyMask;
                info.shift = event.modifierFlags & NSShiftKeyMask;
                
                const NSRect contentRect = [window.contentView frame];
                const NSPoint p = [event locationInWindow];
                
                info.x = p.x;
                info.y = contentRect.size.height - p.y;
                
                return info;
                
            }
            
            NativeWindowKeyInfo CreateKeyInfo(NSWindow* window, NSEvent* event)
            {
                NativeWindowKeyInfo info;
             
                info.ctrl = event.modifierFlags & NSControlKeyMask;
                info.shift = event.modifierFlags & NSShiftKeyMask;
                info.alt = event.modifierFlags & NSAlternateKeyMask;
                
                info.code = NSEventKeyCodeToGacKeyCode(event.keyCode);
                
                return info;
            }
            
            void CocoaWindow::HandleEventInternal(NSEvent* event)
            {
                switch([event type])
                {
                    case NSCursorUpdate:
//                        SetWindowCursor(currentCursor);
                        break;
                        
                    case NSLeftMouseDown:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        if(event.clickCount == 2)
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->LeftButtonDoubleClick(info);
                            }
                        }
                        else
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->LeftButtonDown(info);
                            }
                        }
                        break;
                    }
                        
                    case NSLeftMouseUp:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->LeftButtonUp(info);
                        }
                        break;
                    }
                        
                    case NSRightMouseDown:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        if(event.clickCount == 2)
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->RightButtonDoubleClick(info);
                            }
                        }
                        else
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->RightButtonDown(info);
                            }
                        }
                        break;
                    }
                        
                    case NSRightMouseUp:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->RightButtonUp(info);
                        }
                        break;
                    }
                        
                    case NSMouseMoved:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        info.nonClient = !mouseHoving;
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->MouseMoving(info);
                        }
                        mouseLastX = info.x;
                        mouseLastY = info.y;
                        break;
                    }
                        
                    case NSMouseEntered:
                    {
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->MouseEntered();
                        }
                        mouseHoving = true;
                        break;
                    }
                        
                    case NSMouseExited:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->MouseLeaved();
                        }
                        mouseHoving = false;
                        break;
                    }
                        
                    case NSOtherMouseDown:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        if(event.clickCount == 2)
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->MiddleButtonDoubleClick(info);
                            }
                        }
                        else
                        {
                            for(vint i=0; i<listeners.Count(); ++i)
                            {
                                listeners[i]->MiddleButtonDown(info);
                            }
                        }
                        break;
                    }
                        
                    case NSOtherMouseUp:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->MiddleButtonUp(info);
                        }
                        break;
                    }
                        
                    case NSScrollWheel:
                    {
                        NativeWindowMouseInfo info = CreateMouseInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->HorizontalWheel(info);
                        }
                        break;
                    }
                        
                    case NSKeyDown:
                    {
                        NativeWindowKeyInfo info = CreateKeyInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->KeyDown(info);
                        }
                        break;
                    }
                        
                    case NSKeyUp:
                    {
                        NativeWindowKeyInfo info = CreateKeyInfo(nativeContainer->window, event);
                        
                        for(vint i=0; i<listeners.Count(); ++i)
                        {
                            listeners[i]->KeyUp(info);
                        }
                        break;
                    }
                        
                    case NSFlagsChanged: // modifier flags
                        break;
                        
                    default:
                        break;
                }
            }
        }
    }
}


@implementation CocoaWindowDelegate

- (id)initWithNativeWindow:(INativeWindow*)window
{
    if(self = [super init])
    {
        _nativeWindow = window;
        _sizeState = vl::presentation::INativeWindow::Restored;
    }
    return self;
}

- (void)windowDidMiniaturize:(NSNotification *)notification
{
    _sizeState = vl::presentation::INativeWindow::Minimized;
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
    _sizeState = vl::presentation::INativeWindow::Restored;
}

- (void)windowDidEnterFullScreen:(NSNotification *)notification
{
    _sizeState = vl::presentation::INativeWindow::Maximized;
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    _sizeState = vl::presentation::INativeWindow::Restored;
}

- (void)windowDidMove:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeMoved();
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeGotFocus();

}

- (void)windowDidResignKey:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeLostFocus();
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeAcivate();

}

- (void)windowDidResignMain:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeDeactivate();

}

- (BOOL)windowShouldClose:(id)sender
{
    // !cancel
    return !(dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeClosing();
}

- (void)windowDidResize:(NSNotification *)notification
{
    (dynamic_cast<osx::CocoaWindow*>(_nativeWindow))->InvokeMoved();

}

@end