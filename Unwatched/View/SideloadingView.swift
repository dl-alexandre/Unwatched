import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    func deleteSubscription(_ indexSet: IndexSet) {
        SubscriptionService.deleteSubscriptions(
            sidedloadedSubscriptions,
            indexSet: indexSet,
            container: modelContext.container
        )
    }

    var body: some View {
        let subs = sidedloadedSubscriptions.filter({ !$0.videos.isEmpty })
        ZStack {
            if subs.isEmpty {
                ContentUnavailableView("noSideloadedSubscriptions",
                                       systemImage: "arrow.right.circle",
                                       description: Text("noSideloadedSubscriptionsDetail"))
            } else {
                List {
                    ForEach(subs) { sub in
                        NavigationLink(
                            destination: SubscriptionDetailView(subscription: sub)
                        ) {
                            SubscriptionListItem(subscription: sub)
                        }
                    }
                    .onDelete(perform: deleteSubscription)
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
                .navigationBarTitle("Sideloads", displayMode: .inline)
            }
        }
    }
}

// #Preview {
//    SideloadingView()
// }
