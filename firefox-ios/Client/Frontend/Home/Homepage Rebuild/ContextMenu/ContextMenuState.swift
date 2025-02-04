// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Shared
import Storage

/// State to populate actions for the `PhotonActionSheet` view
/// Ideally, we want that view to subscribe to the store and update its state following the redux pattern
/// For now, we will instantiate this state and populate the associated view model instead to avoid
/// increasing scope of homepage rebuild project.

struct ContextMenuState {
    var site: Site?
    var actions: [[PhotonRowActions]] = [[]]

    private let configuration: ContextMenuConfiguration
    private let windowUUID: WindowUUID
    private let logger: Logger
    weak var coordinatorDelegate: ContextMenuCoordinator?

    init(configuration: ContextMenuConfiguration, windowUUID: WindowUUID, logger: Logger = DefaultLogger.shared) {
        self.configuration = configuration
        self.windowUUID = windowUUID
        self.logger = logger

        guard let site = configuration.site else { return }
        self.site = site

        switch configuration.homepageSection {
        case .topSites:
            actions = [getTopSitesActions(site: site)]
        case .pocket:
            actions = [getPocketActions(site: site)]
        default:
            return
        }
    }

    // MARK: - Top sites item's context menu actions
    private func getTopSitesActions(site: Site) -> [PhotonRowActions] {
        let topSiteActions: [PhotonRowActions]
        if site is PinnedSite {
            topSiteActions = getPinnedTileActions(site: site)
        } else if site as? SponsoredTile != nil {
            topSiteActions = getSponsoredTileActions(site: site)
        } else {
            topSiteActions = getOtherTopSitesActions(site: site)
        }
        return topSiteActions
    }

    private func getPinnedTileActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getRemovePinTopSiteAction(),
                getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getRemoveTopSiteAction(),
                getShareAction(siteURL: site.url)]
    }

    private func getSponsoredTileActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getSettingsAction(),
                getSponsoredContentAction(),
                getShareAction(siteURL: site.url)]
    }

    private func getOtherTopSitesActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        return [getPinTopSiteAction(),
                getOpenInNewTabAction(siteURL: siteURL),
                getOpenInNewPrivateTabAction(siteURL: siteURL),
                getRemoveTopSiteAction(),
                getShareAction(siteURL: site.url)]
    }

    /// This action removes the tile out of the top sites.
    /// If site is pinned, it removes it from pinned and remove from top sites in general.
    private func getRemoveTopSiteAction() -> PhotonRowActions {
        return SingleActionViewModel(title: .RemoveContextMenuTitle,
                                     iconString: StandardImageIdentifiers.Large.cross,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            // TODO: FXIOS-10614 - Add proper actions
        }).items
    }

    private func getPinTopSiteAction() -> PhotonRowActions {
        return SingleActionViewModel(title: .PinTopsiteActionTitle2,
                                     iconString: StandardImageIdentifiers.Large.pin,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            // TODO: FXIOS-10614 - Add proper actions
        }).items
    }

    /// This unpin action removes the top site from the location it's in.
    /// The tile can stil appear in the top sites as unpinned.
    private func getRemovePinTopSiteAction() -> PhotonRowActions {
        return SingleActionViewModel(title: .UnpinTopsiteActionTitle2,
                                     iconString: StandardImageIdentifiers.Large.pinSlash,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            // TODO: FXIOS-10614 - Add proper actions
        }).items
    }

    private func getSettingsAction() -> PhotonRowActions {
        return SingleActionViewModel(title: .FirefoxHomepage.ContextualMenu.Settings,
                                     iconString: StandardImageIdentifiers.Large.settings,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            dispatchSettingsAction(section: .topSites)
            // TODO: FXIOS-10171 - Add telemetry
        }).items
    }

    private func getSponsoredContentAction() -> PhotonRowActions {
        return SingleActionViewModel(title: .FirefoxHomepage.ContextualMenu.SponsoredContent,
                                     iconString: StandardImageIdentifiers.Large.helpCircle,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            guard let url = SupportUtils.URLForTopic("sponsor-privacy") else {
                self.logger.log(
                    "Unable to retrieve URL for sponsor-privacy, return early",
                    level: .warning,
                    category: .homepage
                )
                return
            }
            dispatchOpenNewTabAction(siteURL: url, isPrivate: false, selectNewTab: true)
            // TODO: FXIOS-10171 - Add telemetry
        }).items
    }

    // MARK: - Pocket item's context menu actions
    private func getPocketActions(site: Site) -> [PhotonRowActions] {
        guard let siteURL = site.url.asURL else { return [] }
        let openInNewTabAction = getOpenInNewTabAction(siteURL: siteURL)
        let openInNewPrivateTabAction = getOpenInNewPrivateTabAction(siteURL: siteURL)
        let shareAction = getShareAction(siteURL: site.url)
        let bookmarkAction = getBookmarkAction(site: site)

        return [openInNewTabAction, openInNewPrivateTabAction, bookmarkAction, shareAction]
    }

    // MARK: - Default actions
    private func getOpenInNewTabAction(siteURL: URL) -> PhotonRowActions {
        return SingleActionViewModel(
            title: .OpenInNewTabContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.plus,
            allowIconScaling: true
        ) { _ in
            dispatchOpenNewTabAction(siteURL: siteURL, isPrivate: false)
            // TODO: FXIOS-10171 - Add telemetry
        }.items
    }

    private func getOpenInNewPrivateTabAction(siteURL: URL) -> PhotonRowActions {
        return SingleActionViewModel(
            title: .OpenInNewPrivateTabContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.privateMode,
            allowIconScaling: true
        ) { _ in
            dispatchOpenNewTabAction(siteURL: siteURL, isPrivate: true)
            // TODO: FXIOS-10171 - Add telemetry
        }.items
    }

    private func getBookmarkAction(site: Site) -> PhotonRowActions {
        let bookmarkAction: SingleActionViewModel
        if site.bookmarked ?? false {
            bookmarkAction = getRemoveBookmarkAction()
        } else {
            bookmarkAction = getAddBookmarkAction(site: site)
        }
        return bookmarkAction.items
    }

    private func getRemoveBookmarkAction() -> SingleActionViewModel {
        return SingleActionViewModel(title: .RemoveBookmarkContextMenuTitle,
                                     iconString: StandardImageIdentifiers.Large.bookmarkSlash,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            // TODO: FXIOS-10975 - Add proper actions
        })
    }

    private func getAddBookmarkAction(site: Site) -> SingleActionViewModel {
        return SingleActionViewModel(title: .BookmarkContextMenuTitle,
                                     iconString: StandardImageIdentifiers.Large.bookmark,
                                     allowIconScaling: true,
                                     tapHandler: { _ in
            // TODO: FXIOS-10975 - Add proper actions
        })
    }

    private func getShareAction(siteURL: String) -> PhotonRowActions {
        return SingleActionViewModel(
            title: .ShareContextMenuTitle,
            iconString: StandardImageIdentifiers.Large.share,
            allowIconScaling: true,
            tapHandler: { _ in
                guard let url = URL(string: siteURL, invalidCharacters: false) else {
                    self.logger.log(
                        "Unable to retrieve URL for \(siteURL), return early",
                        level: .warning,
                        category: .homepage
                    )
                    return
                }
                let shareSheetConfiguration = ShareSheetConfiguration(
                    shareType: .site(url: url),
                    shareMessage: nil,
                    sourceView: configuration.sourceView ?? UIView(),
                    sourceRect: nil,
                    toastContainer: configuration.toastContainer,
                    popoverArrowDirection: [.up, .down, .left]
                )

                dispatchShareSheetAction(shareSheetConfiguration: shareSheetConfiguration)
            }).items
    }

    // MARK: Dispatch Actions
    private func dispatchSettingsAction(section: Route.SettingsSection) {
        store.dispatch(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(.settings(section)),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnSettingsSection
            )
        )
    }

    private func dispatchOpenNewTabAction(siteURL: URL, isPrivate: Bool, selectNewTab: Bool = false) {
        store.dispatch(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(
                    .newTab,
                    url: siteURL,
                    isPrivate: isPrivate,
                    selectNewTab: selectNewTab
                ),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnOpenInNewTab
            )
        )
    }

    private func dispatchShareSheetAction(shareSheetConfiguration: ShareSheetConfiguration) {
        store.dispatch(
            NavigationBrowserAction(
                navigationDestination: NavigationDestination(.shareSheet(shareSheetConfiguration)),
                windowUUID: windowUUID,
                actionType: NavigationBrowserActionType.tapOnShareSheet
            )
        )
    }
}
