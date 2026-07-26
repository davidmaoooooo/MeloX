import Foundation

enum SettingsRoute: Hashable {
    case accountHome
    case privateMessages
    case playback
    case playerAppearance
    case lyrics
    case systemPlayback
    case general
    case content
    case downloads
    case skylineLyrics
    case floatingLyrics
    case about
}

struct SettingsCatalogSection: Identifiable {
    let title: String
    let items: [SettingsCatalogItem]

    var id: String { title }
}

struct SettingsCatalogItem {
    let route: SettingsRoute
    let title: String
    let subtitle: String
    let systemImage: String
    let keywords: [String]

    func matches(_ query: String) -> Bool {
        SettingsCatalog.matches(
            query,
            values: [title, subtitle] + keywords
        )
    }
}

enum SettingsCatalog {
    static let sections = [
        SettingsCatalogSection(
            title: "播放与歌词",
            items: [
                SettingsCatalogItem(
                    route: .playback,
                    title: "播放与音频",
                    subtitle: "音质、音量、均衡器、自动混音与播放行为",
                    systemImage: "waveform",
                    keywords: [
                        "高品质",
                        "无损",
                        "上一首",
                        "页面记忆",
                        "交叉淡化",
                    ]
                ),
                SettingsCatalogItem(
                    route: .playerAppearance,
                    title: "播放器外观",
                    subtitle: "背景、封面动画与屏幕常亮",
                    systemImage: "paintbrush",
                    keywords: [
                        "模糊",
                        "色彩",
                        "饱和度",
                        "暂停",
                        "自动锁屏",
                    ]
                ),
                SettingsCatalogItem(
                    route: .lyrics,
                    title: "歌词",
                    subtitle: "样式、排版、翻译、逐字、交互与动画",
                    systemImage: "quote.bubble",
                    keywords: [
                        "Apple Music",
                        "EVA",
                        "文字PV",
                        "字体",
                        "YRC",
                        "伪逐字",
                        "辉光",
                        "刷新率",
                    ]
                ),
            ]
        ),
        SettingsCatalogSection(
            title: "系统与扩展显示",
            items: [
                SettingsCatalogItem(
                    route: .systemPlayback,
                    title: "锁定屏幕与实时活动",
                    subtitle: "系统播放信息、锁定屏幕与灵动岛歌词",
                    systemImage: "lock.display",
                    keywords: [
                        "控制中心",
                        "系统歌词",
                        "Live Activity",
                        "标题格式",
                        "封面",
                        "播放进度",
                    ]
                ),
                SettingsCatalogItem(
                    route: .skylineLyrics,
                    title: "全屏天际歌词",
                    subtitle: "横屏布局、背景文字与动态效果",
                    systemImage: "rectangle.landscape.rotate",
                    keywords: [
                        "横屏",
                        "字号",
                        "漂移",
                        "倾斜",
                        "背景歌词",
                    ]
                ),
                SettingsCatalogItem(
                    route: .floatingLyrics,
                    title: "悬浮窗歌词",
                    subtitle: "画中画歌词、翻译与下一句",
                    systemImage: "pip",
                    keywords: [
                        "画中画",
                        "悬浮歌词",
                        "其他应用",
                        "歌词大小",
                    ]
                ),
            ]
        ),
        SettingsCatalogSection(
            title: "内容与存储",
            items: [
                SettingsCatalogItem(
                    route: .content,
                    title: "发现内容",
                    subtitle: "新碟地区与歌单信息显示",
                    systemImage: "rectangle.stack",
                    keywords: [
                        "华语",
                        "欧美",
                        "韩国",
                        "日本",
                        "播放量",
                    ]
                ),
                SettingsCatalogItem(
                    route: .downloads,
                    title: "下载与缓存",
                    subtitle: "自动缓存、下载任务与本地歌曲",
                    systemImage: "arrow.down.circle",
                    keywords: [
                        "存储",
                        "空间",
                        "触发次数",
                        "缓存音质",
                        "删除下载",
                    ]
                ),
            ]
        ),
        SettingsCatalogSection(
            title: "MeloX",
            items: [
                SettingsCatalogItem(
                    route: .general,
                    title: "通用",
                    subtitle: "启动页面、导航与音乐库记忆",
                    systemImage: "gearshape",
                    keywords: [
                        "默认页面",
                        "上次页面",
                        "首页",
                        "发现",
                        "音乐库",
                        "搜索",
                    ]
                ),
                SettingsCatalogItem(
                    route: .about,
                    title: "关于 MeloX",
                    subtitle: "版本、更新、社区与开源许可",
                    systemImage: "info.circle",
                    keywords: [
                        "GitHub",
                        "Telegram",
                        "更新日志",
                        "检查更新",
                        "声明",
                    ]
                ),
            ]
        ),
    ]

    static func filteredSections(
        matching query: String
    ) -> [SettingsCatalogSection] {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return sections }

        return sections.compactMap { section in
            let items = section.items.filter {
                $0.matches(normalizedQuery)
            }
            guard !items.isEmpty else { return nil }
            return SettingsCatalogSection(
                title: section.title,
                items: items
            )
        }
    }

    static func matchesAccount(_ query: String) -> Bool {
        matches(
            query,
            values: [
                "网易云账号",
                "登录",
                "退出登录",
                "Cookie",
                "个人主页",
                "私信",
                "用户 ID",
            ]
        )
    }

    static func matchesReset(_ query: String) -> Bool {
        matches(
            query,
            values: [
                "恢复播放器默认设置",
                "重置",
                "还原",
                "播放器",
                "歌词",
                "均衡器",
                "自动混音",
            ]
        )
    }

    static func matches(
        _ query: String,
        values: [String]
    ) -> Bool {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return true }

        let searchableText = values
            .joined(separator: " ")
            .lowercased()

        return normalizedQuery
            .split(whereSeparator: \.isWhitespace)
            .allSatisfy { searchableText.contains($0) }
    }

    private static func normalized(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
