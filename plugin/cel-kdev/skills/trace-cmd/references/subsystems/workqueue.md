# Workqueue events (workqueue.h)

| Event | Key Fields | Use |
|-------|-----------|-----|
| workqueue_queue_work | work, function, workqueue | Work item queued |
| workqueue_activate_work | work | Work item activated |
| workqueue_execute_start | work, function | Work handler begins |
| workqueue_execute_end | work, function | Work handler ends |

Pairable: workqueue_queue_work -> workqueue_execute_start (queue
latency); workqueue_execute_start -> workqueue_execute_end
(execution time). Filter by function name to isolate specific
handlers (e.g., svc_xprt_do_enqueue).
