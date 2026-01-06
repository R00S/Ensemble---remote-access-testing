import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:great_list_view/great_list_view.dart';
import '../../providers/music_assistant_provider.dart';
import '../../models/player.dart';
import '../../theme/design_tokens.dart';
import '../common/empty_state.dart';

/// Panel that displays the current playback queue with drag-to-reorder
/// and swipe-left-to-delete functionality
class QueuePanel extends StatefulWidget {
  final MusicAssistantProvider maProvider;
  final PlayerQueue? queue;
  final bool isLoading;
  final Color textColor;
  final Color primaryColor;
  final Color backgroundColor;
  final double topPadding;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const QueuePanel({
    super.key,
    required this.maProvider,
    required this.queue,
    required this.isLoading,
    required this.textColor,
    required this.primaryColor,
    required this.backgroundColor,
    required this.topPadding,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  late AnimatedListController _listController;
  List<QueueItem> _items = [];

  @override
  void initState() {
    super.initState();
    _listController = AnimatedListController();
    _items = widget.queue?.items ?? [];
  }

  @override
  void didUpdateWidget(QueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update items when queue changes
    final newItems = widget.queue?.items ?? [];
    if (newItems != _items) {
      _items = newItems;
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  String _formatDuration(int? durationSeconds) {
    if (durationSeconds == null) return '';
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _handleDelete(QueueItem item, int index) async {
    // Remove from queue via API
    final queueId = widget.queue?.queueId;
    if (queueId != null) {
      await widget.maProvider.api?.queueCommandDeleteItem(queueId, item.queueItemId);
      widget.onRefresh();
    }
  }

  void _handleReorder(int oldIndex, int newIndex) async {
    // Reorder via API
    final queueId = widget.queue?.queueId;
    if (queueId != null && oldIndex != newIndex) {
      final item = _items[oldIndex];
      await widget.maProvider.api?.queueCommandMoveItem(queueId, item.queueItemId, newIndex);
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(top: widget.topPadding + 4, left: 4, right: 16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: widget.textColor, size: IconSizes.md),
                  onPressed: widget.onClose,
                  padding: Spacing.paddingAll12,
                ),
                const Spacer(),
                Text(
                  'Queue',
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: widget.textColor.withOpacity(0.7), size: IconSizes.sm),
                  onPressed: widget.onRefresh,
                  padding: Spacing.paddingAll12,
                ),
              ],
            ),
          ),

          // Queue content
          Expanded(
            child: widget.isLoading
                ? Center(child: CircularProgressIndicator(color: widget.primaryColor))
                : widget.queue == null || _items.isEmpty
                    ? _buildEmptyState(context)
                    : _buildQueueList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState.queue(context: context);
  }

  Widget _buildQueueList() {
    final currentIndex = widget.queue!.currentIndex ?? 0;

    return AutomaticAnimatedListView<QueueItem>(
      list: _items,
      padding: Spacing.paddingH8,
      comparator: AnimatedListDiffListComparator<QueueItem>(
        sameItem: (a, b) => a.queueItemId == b.queueItemId,
        sameContent: (a, b) => a.track.name == b.track.name && a.track.duration == b.track.duration,
      ),
      itemBuilder: (context, item, data) {
        final index = _items.indexOf(item);
        final isCurrentItem = index == currentIndex;
        final isPastItem = index < currentIndex;

        return data.measuring
            ? _buildQueueItem(item, index, isCurrentItem, isPastItem, measuring: true)
            : _buildDismissibleQueueItem(item, index, isCurrentItem, isPastItem);
      },
      listController: _listController,
      reorderModel: AnimatedListReorderModel(
        onReorderStart: (index, dx, dy) => true,
        onReorderFeedback: (index, dropIndex, offset, dx, dy) => null,
        onReorderMove: (index, dropIndex) => true,
        onReorderComplete: (index, dropIndex, slot) {
          _handleReorder(index, dropIndex);
          return true;
        },
      ),
      addLongPressReorderable: true,
      reorderableOptions: const AutomaticAnimatedListReorderableOptions(
        allowedFeedbackYShift: AutomaticAnimatedListAllowedFeedbackYShift.none,
        feedbackDecoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissibleQueueItem(QueueItem item, int index, bool isCurrentItem, bool isPastItem) {
    return Dismissible(
      key: ValueKey(item.queueItemId),
      direction: DismissDirection.endToStart, // Swipe left to delete only
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: EdgeInsets.symmetric(vertical: Spacing.xxs),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        // Don't allow deleting currently playing track
        return !isCurrentItem;
      },
      onDismissed: (direction) {
        _handleDelete(item, index);
      },
      child: _buildQueueItem(item, index, isCurrentItem, isPastItem),
    );
  }

  Widget _buildQueueItem(QueueItem item, int index, bool isCurrentItem, bool isPastItem, {bool measuring = false}) {
    final imageUrl = widget.maProvider.api?.getImageUrl(item.track, size: 80);
    final duration = _formatDuration(item.track.duration);

    return RepaintBoundary(
      child: Opacity(
        opacity: isPastItem ? 0.5 : 1.0,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: Spacing.xxs),
          decoration: BoxDecoration(
            color: isCurrentItem ? widget.primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: ListTile(
            dense: true,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: imageUrl != null && !measuring
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 176,
                        memCacheHeight: 176,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (context, url) => Container(
                          color: widget.textColor.withOpacity(0.1),
                          child: Icon(Icons.music_note, color: widget.textColor.withOpacity(0.3), size: 20),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: widget.textColor.withOpacity(0.1),
                          child: Icon(Icons.music_note, color: widget.textColor.withOpacity(0.3), size: 20),
                        ),
                      )
                    : Container(
                        color: widget.textColor.withOpacity(0.1),
                        child: Icon(Icons.music_note, color: widget.textColor.withOpacity(0.3), size: 20),
                      ),
              ),
            ),
            title: Text(
              item.track.name,
              style: TextStyle(
                color: isCurrentItem ? widget.primaryColor : widget.textColor,
                fontSize: 14,
                fontWeight: isCurrentItem ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.track.artists != null && item.track.artists!.isNotEmpty
                ? Text(
                    item.track.artists!.first.name,
                    style: TextStyle(
                      color: widget.textColor.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (duration.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      duration,
                      style: TextStyle(
                        color: widget.textColor.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (isCurrentItem)
                  Icon(Icons.play_arrow_rounded, color: widget.primaryColor, size: 20)
                else
                  Icon(Icons.drag_handle, color: widget.textColor.withOpacity(0.3), size: 20),
              ],
            ),
            onTap: () {
              // TODO: Jump to this track in queue if MA API supports it
            },
          ),
        ),
      ),
    );
  }
}
