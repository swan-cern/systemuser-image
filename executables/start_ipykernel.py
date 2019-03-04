
if __name__ == '__main__':
    import sys
    del sys.path[0]
    from ipykernel import kernelapp as app
    app.launch_new_instance()
