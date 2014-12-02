#include "..\..\Public\Source\GacUIReflection.h"
#include <Windows.h>

using namespace vl::collections;
using namespace vl::reflection::description;

int CALLBACK WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int CmdShow)
{
	return SetupWindowsDirect2DRenderer();
}

// THE FOLLOWING CODE WILL BE GENERATED BY GacGen.exe -- BEGIN

template<typename TImpl>
class MainWindow_ : public GuiWindow, public GuiInstancePartialClass<GuiWindow>, public Description<TImpl>
{
protected:
	GuiTextList*					listResources;
	GuiButton*						buttonShow;

	void InitializeComponents()
	{
		if (InitializeFromResource())
		{
			GUI_INSTANCE_REFERENCE(listResources);
			GUI_INSTANCE_REFERENCE(buttonShow);

			TImpl* impl = dynamic_cast <TImpl*>(this);
			listResources->SelectionChanged.AttachMethod(impl, &TImpl::listResources_SelectionChanged);
			listResources->ItemLeftButtonDoubleClick.AttachMethod(impl, &TImpl::listResources_ItemLeftButtonDoubleClick);
			buttonShow->Clicked.AttachMethod(impl, &TImpl::buttonShow_Clicked);
		}
	}
public:
	MainWindow_()
		:GuiWindow(GetCurrentTheme()->CreateWindowStyle())
		, GuiInstancePartialClass<GuiWindow>(L"demos::MainWindow")
		, listResources(0)
		, buttonShow(0)
	{
	}
};

// THE FOLLOWING CODE WILL BE GENERATED BY GacGen.exe -- END

class MainWindow : public MainWindow_<MainWindow>
{
	friend class MainWindow_<MainWindow>;
protected:

	void ShowWindowInResource(const WString& name)
	{
		auto resource = GetInstanceLoaderManager()->GetResource(L"Resource");
		auto scope = LoadInstance(resource, L"XmlWindowDemos/" + name + L"/MainWindowResource");
		auto window = UnboxValue<GuiWindow*>(scope->rootInstance);

		window->ForceCalculateSizeImmediately();
		window->MoveToScreenCenter();
		window->Show();

		window->WindowClosed.AttachLambda([=](GuiGraphicsComposition* sender, GuiEventArgs& arguments)
		{
			GetApplication()->InvokeInMainThread([=]()
			{
				delete window;
			});
		});
	}

	void listResources_SelectionChanged(GuiGraphicsComposition* sender, GuiEventArgs& arguments)
	{
		buttonShow->SetEnabled(listResources->GetSelectedItems().Count() == 1);
	}

	void listResources_ItemLeftButtonDoubleClick(GuiGraphicsComposition* sender, GuiItemMouseEventArgs& arguments)
	{
		ShowWindowInResource(listResources->GetItems()[arguments.itemIndex]->GetText());
	}

	void buttonShow_Clicked(GuiGraphicsComposition* sender, GuiEventArgs& arguments)
	{
		vint itemIndex = listResources->GetSelectedItems()[0];
		ShowWindowInResource(listResources->GetItems()[itemIndex]->GetText());
	}
public:
	MainWindow()
	{
		InitializeComponents();
	}
};

void GuiMain()
{
	List<WString> errors;
	GetInstanceLoaderManager()->SetResource(L"Resource", GuiResource::LoadFromXml(L"..\\Resources\\XmlWindowResource.xml", errors));
	MainWindow window;
	window.ForceCalculateSizeImmediately();
	window.MoveToScreenCenter();
	GetApplication()->Run(&window);
}